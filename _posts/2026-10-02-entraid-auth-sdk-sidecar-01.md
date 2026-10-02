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

Now we have our images, let's run it in WSL




