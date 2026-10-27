---
title: Fun with Entra Id Auth SDK (sidecar) part 3 - Web API example
date: 2026-10-12 00:00
categories: [identity]
tags: [Entra, Container]
---

# Introduction

In the previous [article](https://scomnewbie.github.io/posts/entraid-auth-sdk-sidecar-02/), we covered how to consume the Entra Id Auth SDK (DownstreamAPI + AuthHeader). This article will have 2 main goals:

- Show it live how we can implement it with a Powershell API
- Present the pipeline that I've built to generate Powershell web APIs 

{% include note.html content="I've vibe coded the project I will present in this article. I've used several side project to build it quickly (less than 2 hours with Claude)" %}

# History

I'm not a big fan of DSL (Domain Specific Language) when we're talking about creating a web API. Everytime that I discuss with devellopers, they know how to build a Pode API in Pwsh or a Flask in Python. If you think about it, they don't necessary understand how it's working but more how to build it based on a dependancy. Your remove this dependency, or the dependancy is not maintained anymore and it starts to be complicated. What about the security perspective, you don't really control what is done in the backend.

One day, I've watched this [presentation](https://www.youtube.com/watch?v=wmRPvvYX8No) from James Brundage where he explains that a web API/Server is not so complicated at the end of the day (you wait for an HTTP event and you answer with Json) when you understand few things. Since this video, I've built this workflow to build web API on demand.

# Workflow

## High level

- All my projects are based on [Sampler module](https://github.com/gaelcolas/Sampler). I'm usually work on both Github and Gitlab, having this transversal build pipeline help me to be agnostic.
- As usual with Sampler, all functions have associated Pester tests. In addition, I've added Docker tests.
- In all my previous web API side projects I'm using [PSMSALNet](https://www.powershellgallery.com/packages/PSMSALNet/0.1.3) to generate tokens and [ValidateAADJwt](https://www.powershellgallery.com/packages/ValidateAADJwt/0.0.10) to validate the tokens and/or claims. Now I will rely on Entra Id Auth SDK instead.
- All my API runs on Docker containers, usually one. This time I've decided to use a Docker compose to run the two containers side by side.
- Because the Powershell image is not maintained anymore by the Powershell team, I'm using a azurelinux 3.0 (4.0 not GA yet) with the Pwsh tar.gz from the Powershell Github release.
- In the Docker folder I'm modify the file ``Dockerfile.template`` that will be used to build the final Dockerfile artifact. Within this file, you can define required ``TdnfPackages`` or ``InstallModules`` (PSGallery Pwsh modules).
- An ``.env`` is required at the root of this solution to configure the Entra Id Auth SDK container. Here what mine looks like:

![01](/assets/img/2026-10-12/01.png)

To build this project, I've used previously created Pwsh web API (protected with ValidateAADJwt). Then with Claude, I've created few iterations. Then for "fun", I've also included a personnal skill called ``setup-pwsh-environment-with-sampler`` located under the ``.agent/skills`` folder to validate the developpment environment is compliant (Git, Powershell, Sampler resolvedependencies). This is a quick skill that install required tooling if necessary.

## Deep dive

If you want to create a new Pwsh API tommorrow, here the steps:

1. Build a new sampler project

```Powershell
$newSampleModuleParameters = @{ DestinationPath = 'C:\Git\Public'; ModuleType = 'SimpleModule'; ModuleName = 'mydemoAPI'; ModuleAuthor = 'ScomNewbie'; ModuleDescription = 'This module represent a simple web API protected by Entra ID Auth SDK (sidecar)' }
new-sampleModule @newSampleModuleParameters
```
2. Copy the content of the .agent folder if you plan to use AI and you can do a ``git init``.
3. Then, I've opened Claude and I've typed: "Use the skill called setup-pwsh-environment-with-sampler located in the .agent folder to bootstrap this project named mydemoAPI". At this moment, the harness will confirm the project name potentially and will validate the environment and do the first build.ps1 -Tasks noop -ResolveDependency. Few seconds after ere what I see:

![01](/assets/img/2026-10-12/02.png)

4. Add from there, you can simply:
   - Copy the Docker and the .build folder
   - Remove all default generated Sampler files into sources and tests files
   - Copy all Private functions except Get-DownstreamGraphUserOBO.ps1 and Get-DownstreamGraphGroupApp.ps1
   - Copy the Public Start-API.ps1
   - Copy the tests files + Deployment folder + ``TestHelpers.ps1``
   - And finally tweak the start-api and invoke-middleware to remove **all unecessary routes**. Forexemple I've removed the ``fetchuserOBO`` and ``fetchgroupApp``
   - Tweak ``build.yaml`` to add the ``builddockerfile`` stage
   - Tweak both the start-api and invoke-middleware tests files to remove few it blocks related to ``whoami`` or ``fetchuserOBO``
   - Create the dedicated ``.env`` file
   - Then run ``.\build.ps1 -Tasks .`` you should have **100 Pester tests in green**
   - Cd the /output folder from the Docker machine and run ``docker compose --env-file ../.env up``. You should now be able to ``irm "http://localhost:7070/healthz"``

Here the result of the build command:

![](/assets/img/2026-10-12/03.png)

And the result of the Docker compose up:

![](/assets/img/2026-10-12/04.png)

In other words, less than 5 min you get a working web API protected by Entra Auth sidecar SDK configured trough a pipeline that generates a Powershell module, the associated Dockerfile, the Docker compose file and 100+ unit tests? Not bad don't you think?

# Web API

## Start-API

Start-API is the only public function that is executed within this module. This script is using the core \[Net.HttpListener\] class and not extra dependency like Pode for example. This function start an HTTP listener on port 7070 by default trough a runspace. Then we rely on the function called **Wait-Event** built-in command to wait for HTTP events within the previously created listener. Once an event hit the listener, the next step is to go within the middleware (next chapter) to basically accept or drop the request.

If the request is accepted, we go in the switch based on the route and this is where we can use regular Powershell commands or modules. The goal here in addition of doing what you need to do, is to **reply with json data**.

Finnaly, the ``$Event | Remove-Event`` command will remove the HTTP request from the HTTP queue to go back in the ``Wait-Event`` loop.

From a log perspective, a small log stack (``Write-BackendLog`` and ``Write-RequestLog``) is used when you start the API to store both request and backend processes. Both logs are using the Mutex technologies to avoid I/O conflict.

## Invoke-Middleware

This is the interresting part **begins**! Once a request is "catched" by the HTTP listener, the next step is (and must be in fact) the security Middleware. The main goal of this function is to **drop the query as quickly as possible** if needed. Like Start-API, all the routes should be declared and if not, the query will be dropped to avoid wrong behavior. Then another important concept is the extra role validation. Usually, you have multiple roles like regular users, team admins, super admin ... This is why in each route there is the variable $IsValidationRequired that you have to set to true if you want bring more validation.

In this demo API, we can see that the ``healthz`` endpoint **do not require any validation**, the route is open. In other words we won't disucss with the Entra Id Sidecar. Now the ``whoami`` route have the $IsValidationRequired variable set to true but without the $RequiredRoleClaim. In this case, it means we will **only** validate the token** (signature, audience, expiration date, not before...). Then there is for exemple ``fetchuserOBO`` that will **validate the token AND validate the presence of a specific role claim** within the token.

If a validation is required, this is where the command Invoke-sidecar is executed (see below). Then based on the response, the middlewere take an action like validate the extra role or simply return a 403 trough the ``Unauthorized`` command.

Once validated, the ``invoke-middleware`` command simply return a PSCustomObject with few extra properties in addition of the query itself.

## Invoke-Sidecar

And now this is the heart of the magic. This command is used as a wrapper on top of the sidecar. From the command based help, we can see:

```Powershell
Invoke-Sidecar -Path '/DownstreamApi/Graph' -Authorization $auth -Query @{ 'optionsOverride.RelativePath' = 'users/me@contoso.com' }
```

In other words, This command is used:

- From the Middleware to send a request to the /validate endpoint.
- From a function directly (``Get-DownstreamGraphUserOBO`` or ``Get-DownstreamGraphGroupApp``) to call a downstream API.


## TLDR

If tommorrow you need to create an API, the only part that you should modify (related to AuthZ topics) is the ``Start-API`` to add a new route within the switch and ``Invoke-Middleware`` where you have to tweak the 2 switch statements depending on your AuthZ need.

# Pipeline

This is the usual Sampler worflow where you mainly run the ``.\build.ps1 -Tasks .`` command to **test and build** your module. 
 









You will see below that the Entra Id Auth SDK (sidecar) is able to do the [client credential flow](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-client-creds-grant-flow) (application flow) and/or the [On-Behalf-Of flow](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-on-behalf-of-flow) (human flow). Both flows require the usage of a "secret" that is used to validate a "trust". In this article we will use the regular AppId secret, but be aware that you can do both flows with federated credentials to avoid using hardcoded secrets.

Within the [official documentation](https://learn.microsoft.com/en-us/entra/msidweb/agent-id-sdk/security#credential-management), you can see that credential management can be handled in multiple ways. You can today:

* Use Kubernetes clusters and Kubernetes variants like ACA or ECS through workload identity federation
* Use a secret/certificate through Key Vault
* Use a secret/certificate directly (a solution to avoid)

{% include note.html content="I personally don't understand the Key Vault added value except if you rely on a managed identity" %}

For the rest of this article, we will simply use a secret that we will hardcode.


# Docker configuration

Let's recreate a new Docker environment, this time with the additional secret.

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

Compared to the previous article, we've added the 2 lines related to the secret declaration, but we've also added 2 endpoints called Graph and Azure. Those endpoints will be used later when we rely on the `DownstreamApi` route.

# AuthorizationHeader

The AuthorizationHeader endpoint can be used if your web API needs to talk to Graph, Azure or any other backend API. This endpoint is used to fetch a token to access those resources!

## On Behalf flow (OBO)

Remember, in the previous article we generated a token as a user (Authorization code flow) to access our web API (the declared audience). Now, if the web API needs to reach another API as the authenticated user (delegated permission), this is where you will have to use the OBO flow. Let's request a Graph token as a user:

```Powershell
$ClientId = "<your client Id>"
$TenantId = "<your tenant Id>"

# Generate a token to access your web API (previous article)
$token = Get-EntraToken -PublicAuthorizationCodeFlow -ClientId $ClientId -TenantId $TenantId -Resource Custom -CustomResource "api://$ClientId" -Permissions user_impersonation | % AccessToken
```

Now that we have our token to allow our web API to accept the request, let's request another token from your web API (through sidecar) to access Graph API:

```Powershell
irm "http://localhost:8080/AuthorizationHeader/Graph?optionsOverride.Scopes=user.read" -Headers @{ Authorization = "Bearer $token"} | % authorizationHeader
```

If we now decode the generated token in jwt.ms, we will see:

![02](/assets/img/2026-10-06/02.png)

We can clearly see this is a JWT that represents the same identity that signed in to the web API (the $token).

And for fun, if you need to fetch a token to access Azure **as a user**, you can run:

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

We now have a token to reach ARM as the authenticated user.

## Client credential flow

Let's now use the client credential flow. You enter as Francois, but your web API will call the backend API (Graph/Azure) as the Application, not the user anymore (Application permission).

To do this, you will have to add the ``RequestAppToken=true`` override parameter to force the application flow. In addition, don't forget that the scope must now end with ``/.default``.

Here is an example to call Graph API:

```Powershell
irm "http://localhost:8080/AuthorizationHeader/Graph?optionsOverride.RequestAppToken=true&optionsOverride.Scopes=https://graph.microsoft.com/.default" -Headers @{ Authorization = "Bearer $token"} | % authorizationHeader
```

If we now decode the token in jwt.ms:

![07](/assets/img/2026-10-06/07.png)

So the $token is a user token and the generated token now represents the web API itself (9ae134fa... is the object id of my service principal).

Just for fun, for Azure the request will look like this:

```Powershell
irm "http://localhost:8080/AuthorizationHeader/Azure?optionsOverride.RequestAppToken=true&optionsOverride.Scopes=https://management.azure.com/.default" -Headers @{ Authorization = "Bearer $token"} | % authorizationHeader
```

If you now check the server side, you will see that:

- You get retries for free
- In case of an Entra issue, the sidecar tries to reach backup endpoints

![08](/assets/img/2026-10-06/08.png)

We can see that by default MSAL is using an in-memory cache. I don't know if we can use a distributed/serialized cache instead; this is something to be tested for highly used web APIs.

# DownstreamApi

If you don't want to first call ``AuthorizationHeader`` and then call the backend API using the generated token (2 calls), you can fetch the token AND reach the backend API in a single call. In this [article](https://learn.microsoft.com/en-us/entra/msidweb/agent-id-sdk/scenarios/call-downstream-api#when-to-use-each-approach) Microsoft explains when to use which solution, but long story short: unless you need fine-grained control over the received token and/or the backend API result, use ``DownstreamApi``.

## On Behalf flow (OBO)

So now, instead of only fetching a token to access Graph API, let's directly fetch a token AND the associated value in one call:

```Powershell
$ClientId = "<your client Id>"
$TenantId = "<your tenant Id>"

# Generate a token to access your web API (previous article)
$token = Get-EntraToken -PublicAuthorizationCodeFlow -ClientId $ClientId -TenantId $TenantId -Resource Custom -CustomResource "api://$ClientId" -Permissions user_impersonation | % AccessToken
```

{% include note.html content="I forgot to mention it, but instead of a public authorization code flow (human flow), you can also use a client credential flow (application) at the client level. This is where you can imagine a secret/certificate, a managed identity and/or a federated credential as well" %}

```Powershell
irm "http://localhost:8080/DownstreamApi/Graph?optionsOverride.HttpMethod=GET&optionsOverride.Scopes=user.read&optionsOverride.RelativePath=me" -Method POST -Headers @{'Authorization'="Bearer $token"} | % content | ConvertFrom-Json
```

Or if we try to decompose it (we can't use straight splatting):
```Powershell
$base = "http://localhost:8080/DownstreamApi/Graph"

$query = [ordered]@{
    "optionsOverride.HttpMethod"      = "GET"
    "optionsOverride.Scopes"          = "user.read"
    "optionsOverride.RelativePath"    = "me"
}

# Join without escaping the values (matches your original URL byte-for-byte)
$qs = ($query.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "&"

$headers = @{ 'Authorization'= "Bearer $token" }

$params = @{
    Uri     = "$base`?$qs"
    Method  = "POST"
    Headers = $headers
}

Invoke-RestMethod @params | % content | ConvertFrom-Json
```
Let's explain a little. First we call the Graph endpoint (the base URL declared in the Docker command), and note that ``DownstreamApi`` expects a POST method and not a GET! Regarding the call that is made to the backend API (in this case Graph API), even if it's not necessary, I've decided to explicitly expose the default GET method. Yes, we do a POST to call ``DownstreamApi``, but we do a GET to fetch the /me Graph route.

If we now try to do the same thing for Azure and fetch tenant information, here is what the query looks like:

```Powershell
irm "http://localhost:8080/DownstreamApi/Azure?optionsOverride.Scopes=https://management.azure.com/user_impersonation&optionsOverride.RelativePath=tenants?api-version=2020-01-01" -Method POST -Headers @{'Authorization'="Bearer $token"} | % content | ConvertFrom-Json | % value
```

As you can see, the **RelativePath** parameter is the rest of the query you need in order to call the Azure tenant ARM information (tenants?api-version=2020-01-01).

In my case, it returns:

![09](/assets/img/2026-10-06/09.png)

## Client credential flow

This will be almost the same story as before. Let me first consent to a new application permission for my application:

![10](/assets/img/2026-10-06/10.png)

Now let's fetch all users within our tenant:

```Powershell
irm "http://localhost:8080/DownstreamApi/Graph?optionsOverride.RequestAppToken=true&optionsOverride.Scopes=https://graph.microsoft.com/.default&optionsOverride.RelativePath=users" -Method POST -ContentType 'application/json' -Headers @{'Authorization'="Bearer $token"} | % content | ConvertFrom-Json | % value | select -f 2 | % displayName
```

That returns in my case:

![11](/assets/img/2026-10-06/11.png)

And for Azure (just for fun):

```Powershell
irm "http://localhost:8080/DownstreamApi/Azure?optionsOverride.RequestAppToken=true&optionsOverride.HttpMethod=GET&optionsOverride.Scopes=https://management.azure.com/.default&optionsOverride.RelativePath=tenants?api-version=2020-01-01" -Method POST -ContentType 'application/json' -Headers @{'Authorization'="Bearer $token"} | % content | ConvertFrom-Json | % value
```

But this time, because my service principal only has read access to my main Azure tenant (and not the B2C one), the result is:

![12](/assets/img/2026-10-06/12.png)

# Unauthenticated

I'm not sure why I'm exposing this path (YOLO), but if you really don't want to protect your web API, the Entra Id Auth SDK sidecar gives you an option for both the ``AuthorizationHeader`` and ``DownstreamApi`` routes.

To enable it, in the container configuration, you simply have to add **Sidecar__AllowOverrides__CallDownstreamApiUnauthenticated=true**, so for example:

```Bash
docker run --rm -it -p 8080:8080 \
     -e AzureAd__ClientId=$CLIENTID \
     -e AzureAd__TenantId=$TENANTID \
     -e AzureAd__Audience=$AUDIENCE \
     -e AzureAd__ClientCredentials__0__SourceType=ClientSecret \
     -e AzureAd__ClientCredentials__0__ClientSecret=$SECRET \
     -e Sidecar__AllowOverrides__CallDownstreamApiUnauthenticated=true \
     -e DownstreamApis__Graph__BaseUrl=https://graph.microsoft.com/v1.0 \
     -e DownstreamApis__Azure__BaseUrl=https://management.azure.com \
     -e ASPNETCORE_ENVIRONMENT=Development \
     mcr.microsoft.com/entra-sdk/auth-sidecar:1.1.2-azurelinux3.0-distroless
```

A few things to know: you MUST be in **Development** mode to be able to use this "new" ``DownstreamApiUnauthenticated`` endpoint. So for example, I've executed:

```Powershell
irm "http://localhost:8080/DownstreamApiUnauthenticated/Azure?optionsOverride.RequestAppToken=true&optionsOverride.Scopes=https://management.azure.com/.default&optionsOverride.RelativePath=tenants?api-version=2020-01-01" -Method POST | % content | ConvertFrom-Json | % value
```

But honestly, this goes against all the principles of this tool. Don't use it, or please tell me why you absolutely have to use it on your side.

# Conclusion

In this article, we've explored how to call a backend API from your web API thanks to this sidecar technology. We've seen that this tool is very customizable: you can have multiple secret solutions (secret/cert/MI), multiple backend APIs (Graph, Azure, Custom API), with or without AuthN... The more I use it, the more I consider it a must-have tool when you plan to build and expose a web API.
