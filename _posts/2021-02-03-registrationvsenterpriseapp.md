---
title: What a modern application is?
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

# App registration Vs Enterprise application

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

For me, consent is one of the most underestimated part of modern auth. I’ve seen global admins/App admins who click the grant admin consent button just without really understand what they’re doing. And on the other side, I’ve seen clients who click on the consent button without even taking 2 seconds to read what they consented to … But interesting things can happen if you don’t take consent seriously (see below).
Here how I explain consent flow to a non-technical person. When you install a GPS related application on your smartphone, the phone asks you if you’re OK with the idea this app use your GPS chipset to work correctly. If you say yes, the app won’t bother you again. Here it’s the same thing with scopes instead of GPS. When AAD ask you (the user) to consent, AAD will take note you’re consented and won’t bother you again. You can see who’s consented when you check the Service Principal.

You have two types of consent:

- User consent (like with your smartphone) where each user has to do a manual action to consent scopes.
- Admin consent which is where an admin give consent on behalf of all the organization users. In other words, users won’t receive any prompts, it’s already consented 😉.

But who can give admin consent?

- Global admin which we can be translated to god access. A GA can do anything, like give admin consent on any scopes for all users or take control back on any tenant ‘subscription. This is the domain admins group attackers try to get in the “old” AD days.
- Application administration which can do almost everything on app registration and enterprise app except to admin consent Microsoft graph audience.  But an app admin can consent an api exposed by another app which already received admin consent by a GA. This is this RBAC is considered as a high privilege role.

{% include note.html content="In certain cases, you want to be alerted when a RBAC event is generated on your subscription (Even if it’s a GA who decided to look at your sub). You can use this [logic app]((https://github.com/SCOMnewbie/Azure/tree/master/LogicApp/RBAC-Warnings) ) to be alerted." %}

# Demo

Enough Theory, let's "hack" a tenant!

In this demo, we will have 2 tenants. One which belongs to the attacker (full access) and the other one which belongs to your company (will be GA in this demo, but I'm pretty sure worked well is your consent policy was broken). Thanks to Microsoft this "breach" has been mitigated few months ago, but this pattern can sadly be reuse in other IDPs.. I will use the portal to show you what I4ve done, in the next article, we will have some fun to create applications with code.

Let's have some fun! We will build this:

![hack oauth 01](/assets/img/2021-02-03/hack_oauth.png)

First let's go on the attacker tenant (we have full access), and create a new multi tenant app registration called I will pown you. Then give it application mail.read (This scope give full access to read all maibox). Finally, let's generate a secret for this app. You should have something like this:

![hack oauth 02](/assets/img/2021-02-03/hack_oauth_02.png)

So at this point, the attacker just configure within his own tenant an application which can read email. This is a dummy exmample, but it can be "far more critical" like manage directory, write groups,...). For this demo, I will use a pretty cool module called MSAL.PS. It's not an official Powershell SDK, but it help you to generate token using MSAL. So let's now quickly test if our app is working:

```powershell

#Define parameters
$tenantId = <Attacker tenantId>
$AppId = <attacker app registration Id>
$Secret = Read-Host -AsSecureString #secret generated previously
$uri = "An attacker email address"

#Create variables
$uri = "https://graph.microsoft.com/v1.0/users/$UPN/messages"
#Generate Access token for an confidential app
$token = Get-MsalToken -ClientId $appId -ClientSecret $secret -TenantId $tenant -Scopes "https://graph.microsoft.com/.default" -ForceRefresh
#Create header
$Headers = @{
    'Authorization' = $("Bearer " + $token.AccessToken)
    "Content-Type"  = 'application/json'
}
#Request read email
Invoke-RestMethod -Uri $uri -Headers $Headers

```

Now you should be able to read any mailbox from the attacker tenant, which is normal because you run your workflow using a application permission (run as an app, not as a user).

Now this is the interresting part. Imagine now, the attacker starts a phishing attack on your company and a basic user click on a web link and arrive at the AAD authentication page. For this demo, instead of creating a webpage for the phishing attack, we will simply generate a device code authentication (puclic application with no secret shared) using the attacker AppId. So now we're on the basic user side, let's run:

```powershell

#Define parameters
$tenantId = <Customer tenantId>
$AppId = <attacker app registration Id>
$uri = "A customer email address"

#Generate Access token for an public app
$token = Get-MsalToken -ClientId $appId -TenantId $tenant -devicecode
#Create header
$Headers = @{
    'Authorization' = $("Bearer " + $token.AccessToken)
    "Content-Type"  = 'application/json'
}
#Request read email
Invoke-RestMethod -Uri $uri -Headers $Headers

```

Once you've entered the basic user credential, you should see something like this:

![hack oauth 03](/assets/img/2021-02-03/hack_oauth_03.png)

And this is where we can send a BIG THANK YOU to Microsoft. Even is a basic end user can consent every applications, MS required the application to be published. We will discussed about this below, but this technique should block most of these attacks. Now instead of a basic user, let's use a GA account from the customer side to continue the simulation. I'm pretty sure some IDPs didn't fix this attack yet. So Let's imagine we're still our basic user, but for the purpose of this demo, let's use a GA instead. So let's do exactly the same thing but user other creds instead, you should now see:

![hack oauth 04](/assets/img/2021-02-03/hack_oauth_04.png)

Here it's pretty obvious, but let's now imagine a good phishing attack with a good logo, and a real company name... If user does not read the scope and consent, this is where the fun begins! So let's click accept :D.

![hack oauth 05](/assets/img/2021-02-03/hack_oauth_05.png)

The user has now signed in. We don't really care what happen now on the app side. Let's go back on the attacker side and see what we can do now!

```powershell

#Define parameters
$tenantId = <Customer tenantId>
$AppId = <attacker app registration Id>
$Secret = Read-Host -AsSecureString #secret generated previously
$uri = "A customer email address"

#Create variables
$uri = "https://graph.microsoft.com/v1.0/users/$UPN/messages"
#Generate Access token for an confidential app
$token = Get-MsalToken -ClientId $appId -ClientSecret $secret -TenantId $tenant -Scopes "https://graph.microsoft.com/.default" -ForceRefresh
#Create header
$Headers = @{
    'Authorization' = $("Bearer " + $token.AccessToken)
    "Content-Type"  = 'application/json'
}
#Request read email
Invoke-RestMethod -Uri $uri -Headers $Headers

```

And now, the attacker have access to your tenant and can in this case read the email address for the entiere company. And just to fully understand, now we access the company information with a service principal, so we don't care if a user has MFA, reset password or anything like that. We execute our flow through another context ... If we now check the logs, we should see:

Nothing . . . In fact this is not true. We can see in the AAD audit log that my GA account had consented a new application, but when I read the mail from the attacker sice with the secret, I don't see any trace from both the AAD and Enterprise app side. I assume (hope) that MCAS can provide something ...

To be honest, because I was super surprise that I didn't catch any logs, I've decided this time to grant group creation instead of just read.mail. And except this in the AAD audit logs because I did a POST:

![hack oauth 06](/assets/img/2021-02-03/hack_oauth_06.png)

{% include important.html content="I have to admit that I'm surprised. Even with the new experience, the service principal sign-ins is empty ... It seems that MS has some hard time to track client credential flow I guess. I hope this will change in a near future" %}

As you can see, this attack is super simple and in fact rely on the fact that admins have a light governance regarding consent and basic user do not read what they consent to. But for the rest, there is not even a secret exchange!

So Microsoft succeed to "mitigate" this type of attacks because my multi tenant app was unverified, but now imagine an attacker get GA access on a tenant, we can imagine he use this one to jump on another one.

# Tips

Now we start to understand the big picture, what can we do?

- Global admins has to be TRAINED! They have to understand all those concepts and be ready to challenge devellopers. Imagine a GA consent a scope like Group.ReadWrite.All (delete all groups with application permission), things can become bad quickly...

- Train your devellopers. Even if AAD does a good job to require admin consent when needed, for an end user perspective, it's not really a good experience when you receive a wall of scopes to consent at the first login. Developpers should implement dynamic scopes in their application and should understand the principal of least privilege.

- All Enterprise applications have to be monitored to detect overprivileged consented scopes. As we've seen, monitoring sign-ins is not an option today, but monitoring the enterprise app scopes or the audit log when someone consent can be an option. You also have tools like the cloud app security portal or sentinel which can help you to improve your security posture.

- Train your users to read what they consent is not a possible option. But AAD propose few options to avoid making the consent experience too painfull. You can really tweak end user consent options to avoid blocking the consent complitely. Doing this, you can generate a lot of frustration. This is why MS propose some option like allow user to self consent if the publisher is trusted and if the scopes are allowed by the IT team. We can enable also theAdmin workflow help end user to request consent to a GA through a simple button.

# Conclusion

I think now you can admit that an app registration and an enterprise app is not te same thing. Between this article and a previous one, modern authentication should start to be an easy pezy topic. We will continue few topics in a later one, but the big part is done.

Here few take away from this article:

- TRAINED your GA! It's not normal a GA does not understand this scopes concepts.
- If you don't plan to create multi-tenant app, stick to single and try to implement governance/monitoring.
- Start implementing Enterprise app governance. It means implementing a governance (weekly review) and monitoring with tools like cloud app security, Sentinel, Scripts, ...
- Don't forget the public Vs confidential application. Here we've succeed to pown the customer tenant without any secret. Don't store Api key in a public app.
- Consent is underrated, but super important. Make sure you have a proper governance around consent in place.

See you in the next article where we should start to create applications with code!

# references

[Consent](https://docs.microsoft.com/en-us/azure/active-directory/develop/application-consent-experience)

[Malicious OAuth application](https://4sysops.com/archives/the-risk-of-fake-oauth-apps-in-microsoft-365-and-azure/)

[CASB](https://docs.microsoft.com/fr-fr/cloud-app-security/app-permission-policy)

[Fake oauth apps](https://4sysops.com/archives/the-risk-of-fake-oauth-apps-in-microsoft-365-and-azure/)

[single Vs multi tenant](https://docs.microsoft.com/en-us/azure/active-directory/develop/single-and-multi-tenant-apps)

[OIDC in AAD](https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-protocols-oidc)

[Permission and consent](https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-permissions-and-consent)

[How to hack OAuth](https://youtu.be/tbu4CfzP25o)

[App publisher](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-configure-publisher-domain)