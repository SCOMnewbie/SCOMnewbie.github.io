---
title: Kubernetes is not a silver bullet 
date: 2021-08-27 00:00
categories: [powershell]
tags: [Powershell, Container]
---

# Introduction

Before people start to bash me, I just want to clarify few things. I’m not pros or cons Kubernetes (K8s), **I’m actually a K8s n00b** and learn it is in my to-do list. But I understand how it’s working and what people has to do to make it work properly and securely in a production environment. When you talk about environment **lifecycle**, **cluster upgrades** (control plane, nodes, containers), **networking**, **identity and access management**, **resource wasting**, **internal rebilling**, **cluster spreading** to just name a few topics… We can easily say that **yes, this tool can answer most of the needs** but <span style="color:red">**only if you’re prepared with the extra operational tasks and responsibilities this tool require**</span>. Now I think I just start to be tired of discussions where developers just want to go straight in to K8s without even considering other options…

Within this article, we will work with Azure Container Instance (ACI) and Azure function. I will try to demonstrate a recent idea that I plan to use to execute various workflows without too much configuration overhead. During the last article, I’ve explained I need to run scripts that can exceed the 10 minutes limit that Azure Function with consumption SKU has, therefore ACI becomes a perfect fit. Now if we use Azure function to orchestrate your container groups, **how do you manage the state of your variables between all steps**? 

Serverless is stateless, sadly when you have more than one step in your worflow (like step3 depends on step2 which depends on step1) you have to store your state somewhere like a database. But in my case, where I only need to run scripts, I’m only interested in passing variables from one step to another easily and dynamically **without extra infrastructure**.

As usual, this article will use Powershell and I assume the concept can be re-used with other languages. 

{% include important.html content="This demo code is not production ready, here I just want to explain the concept without going to deep." %}

The goal of this article will be to demo a way to execute scripts in a modular manner where all scripts can use the same “concept” without worrying about infrastructure, management, or operation overhead…

# Implementation

The solution look like this:

![Desktop View](/assets/img/2021-08-27/aciv1.png)

1. Is the initial phase where we basically define our dataset of variables we will pass to our pipeline and store in a queue. In addition, we can imagine another Az function with timer trigger which will call the HTTP or directly replace the HTTP one by the timer one if you don’t need external interaction or body parameter.
2. Is when the Az function is triggered by the previous step. Implementing async method like this make our solution more flexible and scalable.
3. Is when a function will ask the ARM fabric to deploy our ACI with a container hosted in a Container Registry (ACR). Once deployed, our container will do his job...
4. Is once the work is done, the container will contact another Az function to store variables in a second queue to keep our variables for next a later step.
5. Is finally when we ask the fabric to clean the container group.

Let’s deploy this solution and provide explanations for each step to explain how everything works…

As usual, the code will be available on Github [HERE](https://github.com/SCOMnewbie/Azure/tree/master/ACI/Simple_Deployment).

## Resource Groups (RG)

We will need two RGs. The **management one which will oversee the orchestration part** (control plane). And the **deployment RG which will basically host all our container groups** (data plane). The big difference between the two (except the infra of course) is that our Az function will have contributor access on the deployment one and reader to the control plane. I consider this as a safety net and of course the contributor role can be tweaked to be more granular if needed.

## Function App

The function app is the angular stone of this idea, we will use it as the orchestrator. Let’s create a **consumption Powershell based function app and then enabled the system managed identity**. Now that our function has a proper identity, let’s **grant it reader role to the management RG and contributor to the deployment RG**.

{% include note.html content="Instead of contributor, you can fine-grained the RBAC with custom roles." %}

To avoid duplicating code between functions, I’ve created a simple **module called loadme** where we will find all functions we will re-use over and over. Thanks to the portal, it’s easy to add this module to our function app. On the **App Service Editor** menu and the click **Go**.

![01](/assets/img/2021-08-27/01.png)

Now you can easily **create the required Modules folder** and then **drag and drop the loadme module files** like this:

![02](/assets/img/2021-08-27/02.png)

At this point, all functions located under this function app will be available to be called.

Now under App files (left menu), make sure your **profile.ps1** looks like this:

![03](/assets/img/2021-08-27/03.png)

And the **requirements.psd1** like that:

![04](/assets/img/2021-08-27/04.png)

At this point, our functions will be able to read/write into our resource groups. In addition, we’re now prepared to connect to Azure with the Az.Accounts module, deployed to it with the Az.Resources module and finally use our own custom code with the loadme one! **We will come back later to this function app to create the functions themselves**…

## User managed Identity (User MSI)

Because we will **create and delete our container group(s) all the time**, if we decide to use a **system managed identity** for our ACI, we will quickly mess up our RBAC table with things like this:

![05](/assets/img/2021-08-27/05.png)

To avoid this, we will create a **user MSI that our ACI will use during the deployment**. Let’s now create it. **Once done, let’s assigned our previously created function app the role Managed identity operator on the user MSI resource itself**. Effectively, the inherited reader access does not grant enough permission when the function app will deploy our ACI with this user MSI identity.

![06](/assets/img/2021-08-27/06.png)

{% include note.html content="For the person(s) still with me, this User MSI part is not really mandatory. It is because our Template Specs will require it, but long story short we will use it in the next article…" %}

## Template specs

I won’t be kind in this section. My first plan was to use the CLI but it’s not efficient to bring it into our Az function runtime. Then, **I’ve tried the Az.ContainerInstance Powershell module which is, sorry to say this, the worse Powershell module that I’ve seen**. Nothing is working, the doc is inaccurate, some cmdlets does not even work, I’m surprised that this module went through testing phases …

The last choice that I had was in fact to deploy an ARM template directly. But if I don’t want to store a state in a database, do you think I want to store an ARM template in a storage account? This is where **Template specs start to shine**. The setup is simple, you create a resource called template specs, and paste the content of the ACI.json file. This is a custom template that I’ve quickly created for this proof of concept where we have to specify a User MSI for later usage. 

## Container Registry (ACR)

Nothing complicated here, create an ACR and sadly make sure the **admin credentials are enabled** … I know it sucks but I didn’t find a way to use Azure AD credentials to fetch a container image. 

Because reader role is not enough again, I’ve granted **contributor role on the ACR resource itself to our function app**. For fine grained RBAC, we have to use custom role again...

![07](/assets/img/2021-08-27/07.png)

# Conclusion



