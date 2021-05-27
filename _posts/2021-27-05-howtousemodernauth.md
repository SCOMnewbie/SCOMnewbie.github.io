---
title: How to use modern authentication
date: 2021-03-24 00:00
categories: [identity]
tags: [identity,Powershell,AAD]
---

# Introduction

I'm learning modern authentications since several months and I still learn things every day! I'm super happy to publicly share what I'm working on my free time. Few weeks ago, I've released a Powershell module to create AAD apps because of the limitations of CLI/Az module for my demos. You can find more information [here](https://scomnewbie.github.io/posts/createaadapplications/). There will be some funny demos with this module later... 

I love Powerhell and the Powershell community. And this is where in fact I've started to play with modern authentications. I wanted to play with Graph from my scripts. Now to be honest Powershell is not where you will be able to get the full benefit of the modern identity platform (AAD). Some more advanced langage better interract with the platform (dynamic consent, identity.web library, conditionnal access context auth request, ...). Does it means that I can't learn modern identity? No of course :).


What this initiative will propose?

* Use Powershell (for now) to explain how you can interract with AAD. Each demo try to focus on a specic aspect. I've tried to put a lot of comments.
* Give you tips trhough demo code comments or functions to use the platform.
* Cheap version of the az module caching but for all applications and scopes.

What this initiative won't do?

* Won't explain what identity is from scratch. You can read my previous articles if you want more information. Here, I assume you have at least the glossary of the subject.



Why did I started this initiative?

- People seems to strugle to understand modern authentication.
- IT persons around me imagine we can interract with Graph only through a AppId/Secret. 
- Because MSAL.PS wasn't easy enough for me to explain in live how and what modern auth is working.


Interract with the identoty platform is not something new with Powerhsll or any other langages. The only ways I'm aware of today is by using the MSAL.PS module or by doing this by yourself. For production type of wotklod, I recommend theMSAL.PS library. The side part is that the documentation is not there and as usual using a lib doesn't help you to understand how the whole thing works.

IMPORTANT: Is this module useful? Yes and no in fact. Even if I will continue to work on this module to add few more flows (OBO + Auth  PKCE code with certs), the MSAL.PS which is not an official MSFT module is relying on the MSAL library. Now where this module can be interresting is to validate tokens (more info later).

# Module features

## Current status

* Auth flow with PKCE with or without secret
* Credential flow
* Device code flow
* Acceess Token validation
* Lot of demos with simple cases

## Future

* On behalf Of flow
* Auth code PKCE with certs*
* Create multi tier demos

# How to use this module

There is two important parts:

* In the psoauth2\psoauth2 folder, you will be able to find the usable Powershell module. You will need to to understand, play, debug the modern authentication flows
* In the examples folders, you will be able to find multiples demo files where I explain differents aspects of what modern auth is and how you can use it. Over the time, I will fill this folder with more complicated cases (multi-tiers app) and with other langages too.

Below is where I will explain each what each case bring to avoid having to read them all.

## Simple usecases

### Prerequisites

* You will need Global admin permission to run those demos (admin consent).
* You will need to use the PSAADApplication module. You can find it in the Example folder or directly [here](https://github.com/SCOMnewbie/PSAADApplication/tree/main/PSAADApplication/PSAADApplication) for the latest version.
* You will need the AZ module and/or the AZ CLI too (for certs demos).
* In some demos, you will need an active subscription with a Keyvault already created.

### Script

#### Confidential app with secret for subscription role assignment

* Script is located [here](https://github.com/SCOMnewbie/psoauth2/blob/main/Examples/01-Script-ConfApp-Secret-AzureAssignment.ps1).
* Takeaways:
  * Simple to implement (dev/test)
  * Make sure you implement a key/secret rotation in your application to avoid expiration (Event based notification)
  * No user assignation with this method
  * AAD audit logs can be challenging
  * You hav to store your secret somewhere (not committed in plaitext in your repo)

* Picture of what we will do:

![01](/assets/img/2021-05-27/01.png)

#### Confidential app with certificate for subscription role assignment

* Script is located [here](https://github.com/SCOMnewbie/psoauth2/blob/main/Examples/02-Script-ConfApp-Cert-AzureAssignment.ps1).
* Takeaways:
  * Certificates are better than secrets when you have a good certificates hygiene in your company. Secrets are catched by proxies or other auditing tools, certificates no.
  * Certificates is more complicated to implement than secrets but it's not impossible. My current user experience is really not optimal for now (more info in the script file). Microsoft should work on this part to make it more accessible.
  * Make sure you implement a key/secret rotation in your application to avoid expiration (Event based notification)
  * No user assignation with this method too
  * AAD audit logs can be challenging
  * Keep your private key safe
  * Use pem KV policy is you plan to use CLI or from a Linux box

* Picture of what we will do:

![02](/assets/img/2021-05-27/02.png)

#### Confidential app with secret to call graph API

* Script is located [here](https://github.com/SCOMnewbie/psoauth2/blob/main/Examples/03-Script-ConfApp-Secret-Application-GraphAPI.ps1).
* Takeaways:
  * This is what you see everwhere on Internet.
  * We need the TeanantId as a new information to provide. We will use exclusively **single tenant app** for now.
  * This request will be executed as an application permission (will have access to all tenant resources)
  * Secret should stay protected
  * Now it's not just CLI or Powershell. You can do this with multiple runtimes. You can find Microsoft libraries [here](https://docs.microsoft.com/en-us/azure/active-directory/develop/reference-v2-libraries) or any certified OIDC libraries [here](https://openid.net/developers/certified/). The concept is still the same.
  * We will use the Graph beta endpoint (following a friends need), but use the V1.0 in production, not the Beta version.

* Picture of what we will do:

![03](/assets/img/2021-05-27/03.png)

#### Confidential app with cert to call graph API

* Script is located [here](https://github.com/SCOMnewbie/psoauth2/blob/main/Examples/04-Script-ConfApp-Cert-GraphAPI.ps1).
* Takeaways:
  * Client credential flow should be used to server to server (no interraction).
  * Because there is no interraction (and so no dynamic scope consent), .default scope has to be use.
  * New-AccessToken with ClientCredentialFlow parameter (psoauth2 module cmdlet) can be used to generate an access token and keep it locally into cache (should work on Linux machine too)
  * psoauth2 module manage local token caching.
  * When you use cert auth, you end up create a custom JWT, you use your local private key to sign the token and on the other side, AAD will decode it with the public one. This is called an assertion.
  * it's doesn't matter if you commit the thumbprint.
  * use pfx KV policy if you plan to use the cert from Windows.

* Picture of what we will do:

![04](/assets/img/2021-05-27/04.png)

#### Public app with NO SECRET delegated permission to call graph API (Auth code flow with PKCE + Device Code)

Context:
    Now the fun really begins. Having over-privileged API that you use with secrets/certs is cool (application permission), but the real benefit of modern authentication is the delegated permission part where you don't need any secrets. The platform will use the permission you have as user and act on behalf of you. In other words, if you can't do things with your account, you won't be able to do it through the API (delegated permissions). In the demo, we will create a public app (no secret/cert), require assignment on it (people have to be assigned to authenticate to it) and as before (with a right scope this time) request privilege action from graph (write user auth methods in the demo and remove user account from the picture).

* Script is located [here](https://github.com/SCOMnewbie/psoauth2/blob/main/Examples/05-Script-Public-Delegated-GraphAPI.ps1).
* Takeaways:
  * You don't necessary need a secret to use modern authentication. 
  * Auth Code with PKCE should be the way to go first (even for confidential apps). We will use the New-AccessToken cmdlet.
  * We will use the device code flow to (with the New-AccessToken cmdlet)
  * The request will run with a delegated permission (on behelf of user privileges)
  * We can assign who can access our app now (in comparison to the client credential flow)
  * Don't forget to read comments even on the verbose lines (lot of useful information)
  * Now in AAD logs, you will see user ABC did XYZ action trough application AppID. In means that if you're a Global admin, you will be able to do GA stuff without commiting any secrets!
  * With user assignment, you can even say, GA1 can use the resource X but not resource Y. (we do the test in the demo)

* Picture of what we will do:

In the demo we're are just talking about Global admins accounts (2 differents accounts), but in the picture we're adding 2 regular users accounts too. The idea of this picture is to explain what delegated permission is. To be able to call your API (at least in this demo), you has to be first allowed to request a token (user assignment) and then you have to have the permission to do an action with your account. In other words, in this picture, only User account A wich is global admin will be able to deactivate a user account.

![04](/assets/img/2021-05-27/05.png)

#### Public app delegated permission with refresh token

Context:
    Being able to call our API with delegated persmisson is cool, but do I have to authenticate every hours to my application? This is where refresh token comes into place. The goal of this demo will be to explain how you can get an access token. As before, read the demo file to have deeper information.

* Script is located [here](https://github.com/SCOMnewbie/psoauth2/blob/main/Examples/06-Script-Public-Delegated-GraphAPI-RefreshToken.ps1).
* Takeaways:
  * All authentication flows does not generate an access token.
  * openid scope allow your app to receive an Id token. This scope is like adding [cmdletbinding] to your function to then be able to use offline_access and so on...
  * offline_access is the scope you have to configure to receive a refresh token
  * Use the oid + sub claim to generate a unique id for a use between all tenants. The profile scope add those claims (check the demo).
  * To play with the refresh token, you will simply use the same command New-AccessToken but only when your access token will be expired (check demo)
  * Funny usage of the PSAADApplication module where I will create 5 pre-configred application with a "simple" swich statement.
  * You can add other information in the claims you will receive in both the Id and Access Token. Check out the joker application (optionalClaims).

* Picture of what we will do:

No picture this time because we only play with AAD this time. No API integration (not the point here).

### API

-TBD-

### Desktop App

-TBD-

### Other cases

    -TBD-

## advanced usecases

### Script

### ... later


# Conclusion



# References