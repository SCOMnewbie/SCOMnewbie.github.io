---
title: What an application is?
date: 2021-02-03 00:00
categories: [identity]
tags: [identity,Powershell,AzureAD, Graph]
---

# Introduction

At the beginning, I wanted to talk about what an application is and how to create it in a single article. Then I’ve started to realize that it’s maybe not a good idea… So, let’s start by explaining the differences between enterprise app Vs App registration and then let’s go deeper in this subject.

The goal of this article will be to explain:

- The difference between app registration and Entepririse application
- What single tenant vs multi tenant means
- What consent is and why we have to consider it seriously
- Security and monitoring auround Oauth permissions
- Public Vs confidential application

# App registration Vs Entperise application

## Introduction

I can't count the number of times devellopers/admins tell me that Microsoft has no idea of what they're doing regarding this topic. "Why they've decided to split the two?", "Why do we have the same information in both pages?", “If the clientID is the same, it means this is the same thing no?” and I can continue with few others... Now usually my answer starts with something like this "You're right, I think you get an idea here. Maybe you shoud start creating your own Identity Provider and compete this gigantic billionaire company which has no idea of what they're doing...". Most of the time, the person in front of me understand it's sarcastic. Now even if there is a reason, I must admit that not obvious when you start.

## App registration

An app registration is literally the definition of the application you’re developing. This is what you register to your identity provider to get the globally unique Client ID (also called app ID) into your personal tenant but also between all tenants in general (more information later with multi-tenant application). 
Within the app registration, you will be able to:

- Configure secrets/certificates. As scripters, we usually use this part to execute our non-interactive scripts as an application.
- Define if it’s a single or a multi-tenant application. Do you want your globally unique app available from other AAD tenants?
- Configure the permissions (scopes) your application will require. Your application may need to use graph API, a storage account, a custom API in the backend…
- Configure the claim configuration. Does your application need for example the IP address of the caller in the client ID token? Or the list of all groups the user belongs to? 
- Configure if it’s a public or a confidential application and which OAUTH flows are authorized. As we’ve seen before, this concept of public/confidential is important. We will discuss more about this topic in future article.
- Define roles your application will expose in the client ID token. If you need to split admins and normal user, you can define roles through the manifest.
- Expose internal API. For example, if you plan to use the delegated permission (on behalf of user right), you will have to expose the user_impersonation permission.
- Configure if you, as a developer are a verified publisher! This is an important point when you plan to do multi-tenant application (see later for more information).

As you can see, the app registration is not just a place you use to generate your secrets for your clientID. This part has a real impact on how your application will behave, how your application is secured and what your application can do. This is where your developer should spend most of this time.

## Enterprise App



An app registration is the definition of your application you're

Enterprise App: 
- Manifestation of the local tenant
- Service Principal (Identity)
  - MSI are service principal behind the scene
- One or more per application (multi tenant)
- In the previous article AzureCLI/AZ Powershell/Graph are in fact App registration that has been published as multi tenant App into one of the MS tenant
- Are in charge of consent 
- Who can acces the app
- Is app available on myapps
- 

App registration:
- Definition of the app
- How token is configured
  **- Permission**
**  - Authorized Authentication flow **
  **- Claim configuration**
  - Verified publisher (later)
  - **SEcret/Certs**
  - Expose API like user_impersonation
  **- Define role of your app (Definition of your app)**
  - **1 tenant**


Multi tenant:
- User use the app
  - App consent 
    - crete an SP in Tenant 2 which will reference App registration App from Tenant1.
      - All the managememrnt is done from tenant2, no relationship between tenant 1 and tenant2 except this App regitration which is the minfestation agian.

Note: Talk about the /common endpoint in your app

  Recap an app registration id you Application that you code in your tenant. Imagine a Graph API based application that all tenant share. Of course, it won't be a custom backend API that only you can access.

Note: Global admin take over > monitor RBAC on your sub, you can use this [logic App](https://github.com/SCOMnewbie/Azure/tree/master/LogicApp/RBAC-Warnings) that I've built.

## Side effect of multi tenant app

Danger
    - Principal of least privilege. Admin has to be trained, admin consent can be super critical.
      - Global admin, application admin, cloud application admin (high privilege) > should be monitored!
    - External
      - ¨Phishing attacks
        - Enable MFA on all users
        - Audit Service principal over privilege apps. Read all files/ ... Pretty simple but devastated concept.

Remediation

  Publisher verication
  implement consent policies (low level permission allowed for the end user otherwise Admin consent)
  Admin workflow help go quicker
  User assignmet (who can explicitely access you app)

Monitoring Service Principal

Cloud App security
Sentinel


  



# references

[Consent](https://docs.microsoft.com/en-us/azure/active-directory/develop/application-consent-experience)
[Malicious OAuth application](https://4sysops.com/archives/the-risk-of-fake-oauth-apps-in-microsoft-365-and-azure/)
[CASB](https://docs.microsoft.com/fr-fr/cloud-app-security/app-permission-policy)
[Fake oauth apps](https://4sysops.com/archives/the-risk-of-fake-oauth-apps-in-microsoft-365-and-azure/)
