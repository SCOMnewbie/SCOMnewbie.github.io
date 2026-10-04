---
title: Fun with Entra Id Auth SDK (sidecar) part 1
date: 2026-10-02 00:00
categories: [identity]
tags: [Entra, Container]
---

# Introduction

I recently discovered an interresting tool called [Entra Id Auth SDK (sidecar)](https://learn.microsoft.com/en-us/entra/msidweb/agent-id-sdk/overview) following my new "hobbit" around AI topics. In addition, the same week, I've also discovered [from Merill's Fernando tweet](https://x.com/merill/status/2103992162258157719) that this is an internal MSFT tool that devellopers are using to protect their applications. 

Long story short, this tool help you to:
- Validate a token
- Generate a token as both **client credential & On Behalf Flow (OBO)**
- Call a downstream api in one call

For people like me that discuss with devellopers on regular basis, this can be a gold mine. I can't enumerate the number of times where a develloper think that if you have a JWT, you're good to go...

So, I've simply decided to spend few hours playing with it, and provide my feedback.

During this article, we will start smooth and imagine you are a develloper that build a web API. For now we will keep AI and web api topics far. Because this is a side car, we will simply use Docker and run straight REST calls.

# App registration

Let's start quickly with the app registration configuration. I know this is not best practice, but to simplify I will create one application that will act as both client and resource (backend api).

Let's create the app and configure it as desktop app with http://localhost

![01](/assets/img/2026-10-02/01.png)

Once registered, configure your application as a backend api and add the user_impersonation scope all allow user flow.

![02](/assets/img/2026-10-02/02.png)

For the fun I will have some roles

![03](/assets/img/2026-10-02/03.png)

And configure groups

![04](/assets/img/2026-10-02/04.png)

And now let's grant some user permission within the service principal

![05](/assets/img/2026-10-02/04.png)

{% include note.html content="I can't add group within this tenant, I will do the test on another one" %}

We should be good to go now, let's configure docker

# Docker configuration

In this article we **won't implement good practices**. We will use a secret where MSFT recommends to use managed identity and we will configure the container to show all logs (devellopement mode + MSAL logs enabled), make sure you follow the [best practices](https://learn.microsoft.com/en-us/entra/msidweb/agent-id-sdk/security) in production.   

First the registry, the **doc is not up to date**, but the registry is located [here](https://mcr.microsoft.com/en-us/artifact/mar/entra-sdk/auth-sidecar/tags) and the latest build that I'm interrested in is `1.1.2-azurelinux3.0-distroless`.

Now we have our images, let's run it in WSL (Simple Ubuntu with Docker engine installed)

```Bash
docker run --rm -it -p 8080:8080 \
     -e ASPNETCORE_ENVIRONMENT=Development \
     -e AzureAd__EnablePiiLogging=true \
     -e Logging__LogLevel__Default=Debug \
     mcr.microsoft.com/entra-sdk/auth-sidecar:1.1.2-azurelinux3.0-distroless
```

And you should see something like this:

![06](/assets/img/2026-10-02/06.png)

Open another Pwsh shell and try

```Powershell
irm "http://localhost:8080/healthz"
```

You should see from the client side:

![07](/assets/img/2026-10-02/07.png)

And from the server side:

![08](/assets/img/2026-10-02/08.png)

And this is my first comment, don't be scared about big errors like this, you will face a lot of them during your experimentation. I don't know if I've missed something but most of the time the error message are NOT user friendly (except this one of course)

So let's stop the container add start it again with more paramters:

```Bash

export TENANTID="<your tenant Id>"
export CLIENTID="<your client Id>"
export AUDIENCE="api://$CLIENTID"

docker run --rm -it -p 8080:8080 \
     -e AzureAd__ClientId=$CLIENTID \
     -e AzureAd__TenantId=$TENANTID \
     -e AzureAd__Audience=$AUDIENCE \
     -e ASPNETCORE_ENVIRONMENT=Development \
     -e AzureAd__EnablePiiLogging=true \
     -e Logging__LogLevel__Default=Debug \
     mcr.microsoft.com/entra-sdk/auth-sidecar:1.1.2-azurelinux3.0-distroless
```

Let's explain few things:

- Regarding the **tenant Id**, it's your call but you have to specify it if you're doing single tenant application which is I guess the default for most of us. As usual you can check MSFT docs if you plan to create multi tenant applications.
- The client Id is kind of useless at this stage but soon it will be mandatory. Long story short this is the Appid that will be use to execute some web calls. Because client and backend api are using the same application, the audience will be close to the same id (by default). If you decide to slice it and separate the two for exemple if you have a single client for multiple backends, in this case the two values will be different.
- For the audience, the main thing you have to know is that if you're using a V1 application (In manifest `accessTokenAcceptedVersion` equal null or 1) the value should looks like `api://clientId` (default value). And if you're using a V2 the value will be only `clientId` (without the api://).

So now before doing anything, let's try our healthz route again

```Powershell
irm "http://localhost:8080/healthz"
```

And now the result should return:

![09](/assets/img/2026-10-02/09.png)


We're now ready to go to the next step!

# Token validation

Remember that for now we don't have any secret anywhere. In this part, we will simulate a simple web API that need to do something based on the result of the token(Is it expired? Is it for me? And few other checks...).

```Bash
OAuth2 Flow: Client → Web API (EntraId-protected) with Validation Sidecar
==========================================================================

                                    ┌───────────────────┐
                                    │                   │
                                    │     Entra ID      │
                                    │  (Authorization   │
                                    │     Server)       │
                                    │                   │
                                    └─────────┬─────────┘
                                        ▲     │
                              (1) Request    │ (2) Issue
                              token for      │ access token
                              Web API        │ (audience =
                              (audience)     │  Web API)
                                        │     ▼
                                 ┌──────┴──────────────┐
                                 │                     │
                                 │       Client        │
                                 │                     │
                                 └──────────┬──────────┘
                                            │
                           (3) Call Web API with
                               Bearer <access token>
                                            │
                                            ▼
┌───────────────────────────────────────────────────────────────────────────┐
│  Container                                                                │
│                                                                           │
│   ┌────────────────────────┐          ┌────────────────────────────────┐  │
│   │                        │  (4) POST│                                │  │
│   │                        │  /validate│         Sidecar               │  │
│   │                        │  + token  │  (Entra ID Auth SDK)          │  │
│   │       Web API          ├──────────►│                               │  │
│   │   (Resource Server)    │          │  Validates token:              │  │
│   │                        │◄──────────┤   - signature                 │  │
│   │                        │  (5)      │   - issuer / audience         │  │
│   │                        │  response │   - expiry                    │  │
│   └───────────┬────────────┘          └────────────────────────────────┘  │
│               │                                                           │
│               ▼                                                           │
│      ┌──────────────────┐                                                 │
│      │ Sidecar response │                                                 │
│      │   valid?         │                                                 │
│      └───┬──────────┬───┘                                                 │
│          │          │                                                     │
│      NO  │          │  YES → returns claims (readable format)             │
│          ▼          ▼                                                     │
│   ┌────────────┐  ┌───────────────────────────────────┐                   │
│   │ Return     │  │ (6) Web API additional authz checks│                  │
│   │ 401 / 403  │  │     on claims:                     │                  │
│   │ drop call  │  │   - specific role?                 │                  │
│   └────────────┘  │   - specific group?                │                  │
│          ▲        │   - specific client (appid)?       │                  │
│          │        └───────────────┬───────────────────┘                   │
│          │                        │                                       │
│          │                checks OK?                                      │
│          │                 │          │                                   │
│          │             NO  │          │  YES                              │
│          └─────────────────┘          ▼                                   │
│                            ┌─────────────────────────────┐                │
│                            │ (7) Proceed — Web API does   │               │
│                            │     its actual work and      │               │
│                            │     returns the response     │               │
│                            └──────────────┬──────────────┘                │
│                                           │                               │
└───────────────────────────────────────────┼───────────────────────────────┘
                                            │
                                            ▼
                                    (8) Response back to Client
```

We can now ask the developpers responsibility is not so high for simple web api:

- Validate you don't have an empty Authorization header except for healthz route.
- Forward the token as quickly as possible to the sidecar
- If you have a proper reply you can proceed.
- And only if you need more validation, you only have to do string validation based on the reply.

If you combine with the idea this pattern can be used on Docker, Kubernetes, ACA/ACI/ECS without any architture change, the added value is pretty high according to me.

So let's try to generate a token from the client and see what the validate should return. On the client Pwsh session type (I'm using my PSMSALNet module, choose whateever solution you like to generate a token). This will open the default web browser to validate your identity. Currently, the only option we have is to authenticate as a user, not an application (need certificate, secret or a managed identity) 

```Powershell
$ClientId = "<your client Id>"
$TenantId = "<your tenant Id>"

$token = Get-EntraToken -PublicAuthorizationCodeFlow -ClientId $ClientId -TenantId $TenantId -Resource Custom -CustomResource "api://$ClientId" -Permissions user_impersonation | % AccessToken
```

If you want to validate if it's a v1 or a v2, you can type:

```Powershell
Start-Process "https://jwt.ms/#access_token=$token"
```

Check the aud claim. api://... equals v1 else v2. **Don't forget this is what the sidecar will validate!**.

Now that we have our token, let's call the "sidecar" (don't forget in a real world, it's your api that should receive this topken and forward it to the sidecar, here for demo purpose we use shortcut)

```Powershell
irm "http://localhost:8080/validate" -Headers @{'Authorization'="Bearer $token"} | % claims
```

Here the response:

![10](/assets/img/2026-10-02/10.png)

{% include note.html content="This is where if you decide to run the container with the v2 instead of the v1 (in this case) you will hit a 401 on client side and if you check the logs server side, you will see IDX10214: Audience validation failed..." %}
