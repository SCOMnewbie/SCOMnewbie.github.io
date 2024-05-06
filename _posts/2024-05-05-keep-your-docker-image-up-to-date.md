---
title: Keep your Docker image up to date 
date: 2024-05-05 00:00
categories: [container]
tags: [Powershell, Container]
---

# Introduction

I’m using containers for my day-to-day job more and more. Yes, containers are great, but containers are not a silver bullet.  You **still have to update them on regular basis**. When you just have your application that is running on top of a runtime, it's easy, you update the FROM and case closed. But what about when you have several dependencies included? This is the goal of this [tiny project](https://github.com/SCOMnewbie/AdminToolsImageGenerator). How do you keep your container image **fully up to date**?

# How it’s working? 

Like all my new Powershell projects, I’m using the [Sampler module](https://github.com/gaelcolas/Sampler) to build, test and publish my ideas. This time, the goal isn’t to publish a new module into the Powershell gallery but more to generate an artefact (Dockerfile), build a new Docker image from it and publish it to a container registry.

## Functions 

I’ve created few private helper functions to fetch the latest stable release of: 
- [Multiple Github projects](https://github.com/SCOMnewbie/AdminToolsImageGenerator/blob/main/source/Private/Get-LatestGithubRepositoryReleaseVersion.ps1)
- [Multiple Hashicorp (now IBM) products](https://github.com/SCOMnewbie/AdminToolsImageGenerator/blob/main/source/Private/Get-LatestStableHashicorpProductVersion.ps1)
- [Kubectl](https://github.com/SCOMnewbie/AdminToolsImageGenerator/blob/main/source/Private/Get-LatestStableKubectlVersion.ps1)

Finally, there is the [New-DockerFileFromTemplate](https://github.com/SCOMnewbie/AdminToolsImageGenerator/blob/main/source/Public/New-DockerFileFromTemplate.ps1) function which, based on a Docker Template file, generates the new Dockerfile with dynamic string replacement. In other words, if you want to add/remove a new software in your container image, you have to modify the [template](https://github.com/SCOMnewbie/AdminToolsImageGenerator/blob/main/source/Files/Dockerfile_Template).

## Tasks 

To help me to interact with Docker (of course you need the docker engine installed on the runner), I’ve created few tasks located under the [generateDockerFile.build.ps1](https://github.com/SCOMnewbie/AdminToolsImageGenerator/blob/main/.build/generateDockerFile.build.ps1) file. For now, a lot of parameters are hardcoded for my need, I may change that in the future.

## Build 

The last part is the [build.yaml file](https://github.com/SCOMnewbie/AdminToolsImageGenerator/blob/main/build.yaml) that is used to orchestrate the automation.  

![01](/assets/img/2024-05-05/01.png)

The main idea is to build the PS module as usual with public/private functions, test the module with the Pester framework to validate the module is working properly, generate a new dockerfile and then publish a new image to my Github container registry. 

Github Action is used to check out the code and generate a new Docker image. As you can see, thanks to Sampler, the job is small: 

![02](/assets/img/2024-05-05/02.png)

## Logs 

If we now check the Github Action logs, we can see that Sampler take care of the bootstrap:

![03](/assets/img/2024-05-05/03.png)

Then Sampler will build the module and run the tests:

![04](/assets/img/2024-05-05/04.png)

If everything goes well, the next step will be to connect to the container registry and build the image:

![05](/assets/img/2024-05-05/05.png)

Conclusion 

I’m not saying I will do this for all my projects, but some people maybe be interested in the process of keeping the generated image up to date from a cron job or another tipe of event. In addition, I’m using the same process (that I don’t explain here) to patch a generated image with [Copacetic](https://github.com/project-copacetic/copacetic) and Trivy before exposing it to my end user.

I hope this article has been useful, see you in the next one.

Cheers