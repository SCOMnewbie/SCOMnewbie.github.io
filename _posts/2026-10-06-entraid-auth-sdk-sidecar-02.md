---
title: Fun with Entra Id Auth SDK (sidecar) part 2 - Token generation
date: 2026-10-06 00:00
categories: [identity]
tags: [Entra, Container]
---

# Introduction

In the previous [article](./2026-10-02-entraid-auth-sdk-sidecar-01.md), we've covered how to create our environment and how to validate tokens. This time, we will explain how your backend API (still no AI topic in this article) can rely on Entra Id Auth SDK (sidecar) to call downstream API like Graph or any other API.

{% include note.html content="Remember, do this only when you've validated the received token" %}

# Time to bring secret

You will see below that Entra Id Auth SDK (sidecar) is able to do [client credential flow](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-client-creds-grant-flow) (application flow) and or [On-Behalf flow](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-on-behalf-of-flow) (human flow). Both flows require the usage of a "secret" that is used to validate a "trust". In this article we will use the regular AppId secret but be aware you can do both flows with federated credentials to avoid using hardcoded secrets.

Within the [official documentation](https://learn.microsoft.com/en-us/entra/msidweb/agent-id-sdk/security#credential-management), you can see that credential management can be handled in multiple ways. You can today:

* Use Kubernetes clusters and Kubernetes variant like ACA, ECS through workload identity federation
* Use secret/certificate through Key Vault
* Use secret/certificate directly (solution to avoid)

{% include note.html content="I personnaly don't understand the Keyvault added value except if you rely on managed identity" %}

For the rest of this article, we will simply use a secret that we will hardcode.


# Docker configuration

Let's re create a new Docker environment this time with the additional secret.

```Bash

export TENANTID="<your tenant Id>"
export CLIENTID="<your client Id>"
export AUDIENCE="api://$CLIENTID"
export SECRET="your secret"

docker run --rm -it -p 8080:8080 \
     -e AzureAd__ClientId=$CLIENTID \
     -e AzureAd__TenantId=$TENANTID \
     -e AzureAd__Audience=$AUDIENCE \
     -e AzureAd__ClientCredentials__0__SourceType=ClientSecret \
     -e AzureAd__ClientCredentials__0__ClientSecret=$SECRET \
     -e DownstreamApis__Graph__BaseUrl=https://graph.microsoft.com/v1.0 \
     -e DownstreamApis__Azure__BaseUrl=https://management.azure.com \
     -e ASPNETCORE_ENVIRONMENT=Development \
     -e AzureAd__EnablePiiLogging=true \
     -e Logging__LogLevel__Default=Debug \
     mcr.microsoft.com/entra-sdk/auth-sidecar:1.1.2-azurelinux3.0-distroless
```

Compared to the previous article, we've added the 2 lines related to the secret declaration but we've also added 2 endpoints called Graph and Azure. Those endpoints will use later when we will rely on the `DownstreamAPI` route.

# AuthorizationHeader

The AuthorizationHeader endpoint can be used if your web API need to discuss with Graph, Azure or any other backend API. This endpoint is used to fetch a token to access those resources!

## On Behalf flow (OBO)

Remember in the previous article, we've generated a token as a user (Authorization code flow) to access our web API (the declared audience). Now if the web API need to reach another API as the authenticated user, this is where you will have to use the OBO flow. Let's request a graph token as a user:

```Powershell
$ClientId = "<your client Id>"
$TenantId = "<your tenant Id>"

# Generate a token to access your web API (previous article)
$token = Get-EntraToken -PublicAuthorizationCodeFlow -ClientId $ClientId -TenantId $TenantId -Resource Custom -CustomResource "api://$ClientId" -Permissions user_impersonation | % AccessToken
```

Now that we have our token to allow our web API to accept the request, let's request another token from your web API (through sidecar) to access Graph API:

```Powershell
irm "http://localhost:8080/AuthorizationHeader/Azure?optionsOverride.Scopes=user.read" -Headers @{ Authorization = "Bearer $token"} | % authorizationHeader
```

If we now decode the generated token to jwt.ms, we will see:

![02](/assets/img/2026-10-06/02.png)

We can clearly see this is a JWT that represent the same identity that sign-in to the web api (the $token)

And for fun, if we you need to fetch a token to access Azure **as a user**, you can run:

```Powershell
irm "http://localhost:8080/AuthorizationHeader/Azure?optionsOverride.Scopes=https://management.azure.com/user_impersonation" -Headers @{ Authorization = "Bearer $token"} | % authorizationHeader
```

If you don't grant the permission within your application, you should receive this error message:

![03](/assets/img/2026-10-06/03.png)

Now if you grant the application:

![04](/assets/img/2026-10-06/04.png)

and retry, you should now see:

![05](/assets/img/2026-10-06/05.png)

and if you decode the token:

![06](/assets/img/2026-10-06/06.png)

We can a token to reach ARM as authenticated user.

## Client credential flow








```Powershell
irm "http://localhost:8080/AuthorizationHeader/Azure?optionsOverride.RequestAppToken=true&optionsOverride.Scopes=https://graph.microsoft.com/.default" -Headers @{ Authorization = "Bearer $token"} | % authorizationHeader
```
































Let's start quickly with the app registration configuration. I know this is not best practice, but to simplify I will create one application that will act as both client and resource (backend api).

Let's create the app and configure it as desktop app with http://localhost. As usual with me, my client will be my Pwsh shell.

![01](/assets/img/2026-10-02/01.png)

Once registered, configure your application as a backend API and add the user_impersonation scope to allow the user flow.

![02](/assets/img/2026-10-02/02.png)

For the fun I will have some roles

![03](/assets/img/2026-10-02/03.png)

And configure groups

![04](/assets/img/2026-10-02/04.png)

And now let's grant some user permissions within the service principal

![05](/assets/img/2026-10-02/05.png)

{% include note.html content="I can't add a group within this tenant, I will do the test on another one" %}

We should be good to go now, let's configure Docker

# Docker configuration

{% include warning.html content="We won't use best practices, make sure you follow the [best practices](https://learn.microsoft.com/en-us/entra/msidweb/agent-id-sdk/security) in production" %} 

First the registry: the **doc is not up to date**, but the registry is located [here](https://mcr.microsoft.com/en-us/artifact/mar/entra-sdk/auth-sidecar/tags) and the latest build that I'm interested in is `1.1.2-azurelinux3.0-distroless`.

Now that we have our image, let's run it in WSL (a simple Ubuntu with the Docker engine installed)

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

And this is my first comment: don't be scared by big errors like this, you will face a lot of them during your experimentation. I don't know if I've missed something, but most of the time the error messages are NOT user friendly (except this one, of course).

So let's stop the container and start it again with more parameters:

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

- Regarding the **tenant Id**, it's your call, but you have to specify it if you're building a single-tenant application, which is, I guess, the default for most of us. As usual, you can check the MSFT docs if you plan to create multi-tenant applications.
- The client Id is kind of useless at this stage, but soon it will be mandatory. Long story short, this is the AppId that will be used to execute some web calls. Because the client and backend API are using the same application, the audience will be close to the same id (by default). If you decide to slice it and separate the two, for example if you have a single client for multiple backends, then the two values will be different.
- For the audience, the main thing you have to know is that if you're using a V1 application (in the manifest, `accessTokenAcceptedVersion` equals null or 1) the value should look like `api://clientId` (default value). And if you're using a V2, the value will be only `clientId` (without the api://).

So now before doing anything, let's try our healthz route again

```Powershell
irm "http://localhost:8080/healthz"
```

And now the result should return:

![09](/assets/img/2026-10-02/09.png)


We're now ready to go to the next step!

# Token validation

Remember that for now we don't have any secret anywhere. In this part, we will simulate a simple web API that needs to do something based on the result of the token (Is it expired? Is it for me? And a few other checks...).

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

We can now see that the developer's responsibility is not so high for a simple web API:

- Validate that you don't have an empty Authorization header, except for the healthz route.
- Forward the token as quickly as possible to the sidecar.
- If you get a proper reply, you can proceed.
- And only if you need more validation, you simply have to do string validation based on the reply.

If you add to this the idea that this pattern can be used on Docker, Kubernetes, ACA/ACI/ECS without any architecture change, the added value is pretty high in my opinion.

So let's try to generate a token from the client and see what validate should return. In the client Pwsh session, type the following (I'm using my PSMSALNet module; choose whatever solution you like to generate a token). This will open the default web browser to validate your identity. Currently, the only option we have is to authenticate as a user, not as an application (which would need a certificate, secret or a managed identity).

```Powershell
$ClientId = "<your client Id>"
$TenantId = "<your tenant Id>"

$token = Get-EntraToken -PublicAuthorizationCodeFlow -ClientId $ClientId -TenantId $TenantId -Resource Custom -CustomResource "api://$ClientId" -Permissions user_impersonation | % AccessToken
```

If you want to validate if it's a v1 or a v2, you can type:

```Powershell
Start-Process "https://jwt.ms/#access_token=$token"
```

Check the aud claim: if it starts with `api://` it's a v1, otherwise it's a v2. **Don't forget this is what the sidecar will validate!**

Now that we have our token, let's call the "sidecar" (don't forget that in the real world, it's your API that should receive this token and forward it to the sidecar; here, for demo purposes, we take a shortcut).

```Powershell
irm "http://localhost:8080/validate" -Headers @{'Authorization'="Bearer $token"} | % claims
```

Here is the response:

![10](/assets/img/2026-10-02/10.png)

{% include note.html content="This is where if you decide to run the container with the v2 instead of the v1 (in this case) you will hit a 401 on client side and if you check the logs server side, you will see IDX10214: Audience validation failed..." %}

# Extra

Because I wasn't able to validate with my first tenant, I just wanted to confirm on a tenant with P1 licenses that even the groups claim can be used in the validation process. Here is the proof:

![11](/assets/img/2026-10-02/11.png)

# Conclusion

In this article, we've explained the Entra Id Auth SDK (sidecar) "feature" and we've started with the first step, which is the validation process (and which must be your first step as a developer). What I like with this pattern is that you don't really care if you decide to implement your backend API in Go, Rust or any language where you don't necessarily have a token validation library (though today there might already be one!). In the next article, we will play with both the ``AuthorizationHeader`` and ``DownstreamApi`` routes.
