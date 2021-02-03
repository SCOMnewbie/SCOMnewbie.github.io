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

{% include warning.html content="An app registration is a one to many tenant relationship. Keep in mind that you don't have an AZ CLI/Powershell app registration in your tenant, only Microsoft has." %}

## Enterprise App

An enterprise app, or service principal (SP), is a local tenant representation of an app registration. The SP reference an app registration which has been declared within the local tenant or in a remote one (multi-tenant app). For scripters, this is what you’re using when you do your az login with the potential secret/certificate that you have to rotate (You rotate it right? You don’t check the never expire 😊). Then Microsoft proposes a service called Managed service Identity (MSI) which basically is a service principal in the back end, but they are in charge of rotating the secret for you.

-	Manage who can access your application in your tenant. You will have to be authenticated to use this application, so you can decide who can use it or not with user or group assignment.
-	Monitore who access your application. Every sign-ins are tracked and can be filtered or exported from the portal.
-	Monitore who gave their consents to your application on which specific scope.
-	Configure conditional access.
-	GO DEEP SAML/ OTHER TYPE Of Autehtn

As you can see, the entperprise app oversees a lot of other topics in parallel of app registration and there is no overlap. Enterprise app is more about management around an application. Usually this part is more covered by IT admins instead of developers.

{% include warning.html content="An entperprise app is a many to one relationship. We've seen that there is only one app registration for all tenants, but multiple SP can reference this app registration" %}

# Single tenant Vs multi tenant application

Let's start with a multi tenant picture:

![registrationvsenterpriseapp 01](/assets/img/2021-02-03/singlemultitenant.png)

To clarify this picture, as a customer, there no security concerns with the multi-tenant app if you read and agree the required application’ scope (see danger section below). In other words, it’s not because your SP reference an app registration located in another tenant that you or them will be able to access data located in your/their subscription.

{% include note.html content="Rule of thumb: If you know in your company you only have one tenant and does not create application for external customers, always create a single tenant app. Doing this your employees and guest accounts (B2B) will be able to access it and you’re improving your security posture. In addition, it’s pretty simple to implement infrastructure tests on this parameter as monitoring." %}

Last point, without going too deep. Open ID Connect (OIDC) is a layer on top of OAUTH2.0 which give you for OIDC an Id Token and for OAUTH an Access and a Refresh token.  Both are Authentication/Authorization protocols that we consume through different connection flows (more information later). Today we should use something called the V2.0 endpoint which give you all the latest features the identity platform can offer. In short what does it means:
For single tenant app, you should hit (or hardcode if you prefer) the endpoint https://login.microsoftonline.com/'Tenant Id or tenant Name'/oauth2/v2.0/authorize and for a multi-tenant app https://login.microsoftonline.com/common/oauth2/v2.0/authorize. As you can imagine for a multi-tenant app, you specify common magic name, and let the platform find the right tenant for you.

{% include warning.html content="Important: Imagine you want to provide an app to only few tenants, you will have to handle it from your app itself. Basically, in the ID token you will receive, if it’s not “allowed” drop the query." %}

{% include note.html content="Microsoft does not recommend decoding the Access token (AT) in your application but the ClientID instead. An AT is design to grant access to an application and shouldn’t be touched. Microsoft explain that “tomorrow”, they can encrypt this token with more than a base64 encryption." %}


# Consent




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
[single Vs multi tenant](https://docs.microsoft.com/en-us/azure/active-directory/develop/single-and-multi-tenant-apps)
[OIDC in AAD](https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-protocols-oidc)