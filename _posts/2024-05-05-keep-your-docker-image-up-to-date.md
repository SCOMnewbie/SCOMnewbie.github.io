---
title: Keep your Docker image up to date 
date: 2024-05-05 00:00
categories: [container]
tags: [Powershell, Container]
---

# Introduction

I’m using containers for my day-to-day job more and more. Yes, containers are great, but containers are not a silver bullet.  You **still have to update them on regular basis**. When you just have your application that is running on top of a runtime, it's easy, you update the FROM and case closed. But what about when you have several dependencies included? This is the goal of this tiny project. How do you keep your container image **fully up to date**?

# How it’s working? 

Like all my new Powershell projects, I’m using the [Sampler module](https://github.com/gaelcolas/Sampler) to build, test and publish my ideas. This time, the goal isn’t to publish a new module into the Powershell gallery but more to generate an artefact (Dockerfile), build a new Docker image from it and publish it to a container registry.

## Functions 

I’ve created few private helper functions to fetch the latest stable release of: 
- [Multiple Github projects](https://github.com/SCOMnewbie/AdminToolsImageGenerator/blob/main/source/Private/Get-LatestGithubRepositoryReleaseVersion.ps1)
- [Multiple Hashicorp (now IBM) products](https://github.com/SCOMnewbie/AdminToolsImageGenerator/blob/main/source/Private/Get-LatestStableHashicorpProductVersion.ps1)
- [Kubectl](https://github.com/SCOMnewbie/AdminToolsImageGenerator/blob/main/source/Private/Get-LatestStableKubectlVersion.ps1)

Finally, there is the [New-DockerFileFromTemplate](https://github.com/SCOMnewbie/AdminToolsImageGenerator/blob/main/source/Public/New-DockerFileFromTemplate.ps1) function which, based on a Docker Template file, generates the new Dockerfile with dynamic string replacement. In other words, if you want to add/remove a new software in your container image, you have to modify the [template](https://github.com/SCOMnewbie/AdminToolsImageGenerator/blob/main/source/Files/Dockerfile_Template).

## Tasks 

To help me to interact with Docker, I’ve created few tasks located under the generateDockerFile.build.ps1(https://github.com/SCOMnewbie/AdminToolsImageGenerator/blob/main/.build/generateDockerFile.build.ps1) file. For now, a lot of parameters are hardcoded for my need, I may change that in the future. 

## Build 

The last part is the build.yaml file(https://github.com/SCOMnewbie/AdminToolsImageGenerator/blob/main/build.yaml) that is used to orchestrate the automation.  

<Image build> 

The main idea is to build the PS module as usual with public/private functions, test the module to validate the module is working properly, generate a new dockerfile and then publish it to my Github container registry. 

Github Action is used to check out the code and generate a new Docker image. As you can see, thanks to Sampler, the job is pretty small: 

<image CI> 

## Logs 

If we now check the Github Action logs, we can see: 

... 

Conclusion 

I’m not saying I will do this for all my projects, but some people maybe be interested in the process of keeping the generated image up to date from a cron job or another time of event. In addition, I’m using the same process (that I don’t explain here) to patch a generated image with Copacetic and Trivy before exposing it to my end user. I hope this article has been useful to some of you, see you for the next one. 

I've discovered today that admin consent is not necessary mandatory for your custom APIs. I don't know if it's something that most people know but at least to me this is new, here the story!

Usually, an IT team oversee the Entra ID overall health. Those global admins are in charge to not consent any dangerous permissions like "application.readwrite.all" or mail.readwrite.all... Now when you create your own APIs, this is the same thing, you create your backend API app registration, enabled the "exposed an API", add the scope if you need to expose your API to humans and then you create a ticket to ask a global admin to consent that your client app (another app registration) can request a token to Entra. The problem that I always have with this way is that it's time consuming. Maybe it can be usefull in certain scenarios, but having to ping GA everytime to consent your client application (appid you know and potentially own) to access your backend API (appId you own) seems not optimal...

This is where I've discovered the "Authorized client applications":

![01](/assets/img/2023-11-30/01.png)

What has been new to me is that this feature is not just about consent!

{% include note.html content="I assume you know how to configure an Entra App in this article." %}

# Human flow

You want to expose your API that **YOU OWN** (the app registration) to users (not application), the first step is to create your scope:

![02](/assets/img/2023-11-30/02.png)

This is now the new part for me. If you know the appId of the client(s) that will consume your api, you can declare those to the Authorized client section where you will say this client AppId will be able to consume scope access_asuser in this case.

If you now switch to the client side where you want to consume this API as you can see the api permission is not set:

![03](/assets/img/2023-11-30/03.png)

and of course the appId of the client is what you've declared in the Authorized client:

![04](/assets/img/2023-11-30/04.png)

You can also configure the app assignment required, it won't change the behavior. Now if you try to generate a token, you have the usual interactive flow and once authenticated:

![05](/assets/img/2023-11-30/05.png)

You can request a token without the admin consent :o.

If you check the token, you can see the audience is the backend api:

![06](/assets/img/2023-11-30/06.png)

# Non Human flow

What about application, do you think it work? Of course it works :D. Small disclaimer if you enforce at your company level the **App assignment required** on all your enterprise apps, you will have to use Graph Explorer to assign manually your client service principal to your backend Enterprise App.

![07](/assets/img/2023-11-30/07.png)

Where the resourceId is your backend api objectId service principal, the principalId the client objectId service principal (Enterprise app) an in this case I've assigned the default roleId with the null guid. Once done, we should see this under the backend api enterprise app:

![08](/assets/img/2023-11-30/08.png)

Of course, because I will now use the client credential flow, I have to create a secret on the client side, and once done:

![09](/assets/img/2023-11-30/09.png)

# Conclusion

To conclude, I find this solution interesting when you own the app to not bother the GA for the admin consent part but I don't know, for me something is missing in term of visibility for the people who oversee the service.

I hope this article has been useful, see you in the next one.

Cheers