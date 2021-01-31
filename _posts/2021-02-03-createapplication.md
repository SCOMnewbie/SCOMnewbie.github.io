---
title: What an application is and how to create it!
date: 2021-02-à3 00:00
categories: [identity]
tags: [identity,Powershell,AzureAD, Graph]
---

# Introduction

During this learn modern authentication journey, one day you will have to create an application. But what an application is? What can we do with it? How can I create one? This is what I will try to explain during this article. 
The goal of this article will be to explain:

- Single tenant Vs multi tenant application
- Difference between App registration and Enterprise application
- Consents
- Public Vs confidential application
- Few ways to create an application (ARM & template spec/Pulumi&Terraform/Custom with Graph)

# Single tenant Vs multi tenant application

## Definition

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
  - Permission
  - Authorized Authentication flow 
  - Claim configuration
  - Verified publisher (later)
  - SEcret/Certs
  - Expose API like user_impersonation
  - Define role of your app (Definition of your app)
  - 1 tenant


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
        - Audit Service principal over privilege apps. Read all files/ ...



# references

[Consent](https://docs.microsoft.com/en-us/azure/active-directory/develop/application-consent-experience)
[Malicious OAuth application](https://4sysops.com/archives/the-risk-of-fake-oauth-apps-in-microsoft-365-and-azure/)
[CASB](https://docs.microsoft.com/fr-fr/cloud-app-security/app-permission-policy)
