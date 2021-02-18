---
title: Passwordless deployment from anywhere with Azure ARC
date: 2021-02-20 00:00
categories: [identity]
tags: [identity,Powershell,ARC]
---

# Introduction

Instead of re-inventing the wheel, I will simply paste this definition that I've found in the Azure ARC overview. "Azure Arc enables you to manage your entire environment, with a single pane of glass, by projecting your existing resources into Azure Resource Manager. **You can now manage virtual machines, Kubernetes clusters, and databases as if they are running in Azure**." ARC is not a simple product, but a set of functionalities where you can pick and choose what you’re interested in. Today, our focus will be on **ARC for servers which is GA**.

Following a video @AzureAndChill and @ChristosMatskas published on their [425](https://www.youtube.com/channel/UCIPMDupgTRsJY5sxcdBEtCg) channel, I've discovered that the **ARC agent exposes a local identity endpoint** you can play with to get an access token like you do in Azure directly with a VM for example.

Now what does it mean?

- No more chicken egg problem where you must have a secret to access your vault which hosts all your other secrets.
- You can do any actions on any destinations (On-premises, AWS,GCP,…) without commit a single password in your repo (dduuhh) or the pipeline provider (Github, AzDO, Gitlab,…). The counter part is that you must use today a self-hosted agent. I hope tomorrow GH/AzDO will provide this feature with their runners directly.
- Your developers do not need to know any password. You provide only references to password, not the password itself.
- Even if it’s not officially supported, I know ARC is working well on Windows 10. It’s cool to access a Keyvault from a local dev machine without providing a password in a config file.
- This part of ARC is free of charge. Only the guest policy usage is not free, but we don’t need it here.

![01](/assets/img/2021-02-20/01.png)

{% include note.html content="If you want to go deeper in the ARC subject, Thomas Maurer (mister hybrid cloud) published a nice [article](https://www.thomasmaurer.ch/2020/12/get-started-with-the-azure-arc-jumpstart/) which summarize what ARC is." %} 
I don’t know for you, but I’m excited to see what we will do in this demo, let’s start!

# Context and Managed Identity

For this article, I've **enrolled my local dev machine to ARC**, there is a lot of good documentation, I won't cover this part. Once the onboarding done, you should now have a **new Service Principal** (Enterprise Application) which represents the identity of our dev machine or our self-hosted runner in your pipeline. My plan in this article will be to see what we can do from our local machine compared to what we can do from Azure directly with [managed identities]( https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview).
To help us in this article, I've built a small **function to generate access tokens for various audiences** like Keyvault, ARM and so on... You can find the script [here](https://github.com/SCOMnewbie/Azure/blob/master/Identity-AAD/New-ARCAccessTokenMSI.ps1).

{% include warning.html content="I'm sorry, since few days, Windows is considering my "invoke-expression" as a threat and** Defender is blocking it** ... For now, don't hesitate to review the code, and copy/paste or dot source the functions in your console to load it in memory." %}

```powershell
#Load our function New-ARCAccessTokenMSI in memory.
# UPDATE: Windows consider today this script as a threat ... Let's copy paste it in your console instead.
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/SCOMnewbie/Azure/master/Identity-AAD/New-ARCAccessTokenMSI.ps1'))
# Generate an access token for Keyvault
$KVToken = New-ARCAccessTokenMSI -Audience Keyvault

```

Now you should have received an access token for the Keyvault audience. You can use [JWT.ms](https://jwt.ms/) to verify/check few interesting things:

- The aud property should be: https://vault.azure.net. It's normal, as explain in previous article, the audience is an important part of the modern auth world. Here it's not an access token that we will be able to use to access graph or ARM, but only Keyvault endpoint.
- The appId property which is as the name sugest, the Id of your service principal. You should copy it somewhere for a later usage in this demo.
- The appidacr property which explains we've used certificate to authenticate. Pretty cool no?
- The ver property which is equal to 1.0. It means ARC today can not use the 2.0 Microsoft Identity endpoint. It's not a big deal, but it's interresting to know.

Now we have our token, let's play with Keyvault!

# Keyvault

To simplify the demo, I've created another function which can get a secret from a Keyvault using REST call and access token. As before, you can verify the wrapper function [here](https://github.com/SCOMnewbie/Azure/blob/master/Identity-AAD/Get-KeyvaultSecret.ps1).

{% include note.html content="This part won't be free, I'm pretty sure Keyvault (KV) does not provide a free SKU." %}

The goal of this demo will be to get a seret value from a KV, so what do we need? A Keyvault (thx captain obvious!). I won't cover this part, but here what we need for this demo:

- Create a Keyvault with <span style="color:red">**Role based access policies enabled**</span>. For this demo let's called it MyKeyvault
- Create a Secret and it's value called MySuperSecret for this demo.

```powershell
#In the same console, let's load the wrapper function
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/SCOMnewbie/Azure/master/Identity-AAD/Get-KeyvaultSecret.ps1'))
#Let's now grob our secret from anywhere (On-premises, AWS, GCP, ...) without ANY password!
Get-KeyvaultSecretValue -KeyVaultName "MyKeyvault" -SecretName "MySuperSecret" -AccessToken $KVToken
```

And voilà, you've fetched a secret value from Keyvault from a machine not necessary hosted on Azure without any password. So now your local dev machine has to be proper secured to avoid malicious actions. But now reproduce this steps from a self hosted agent, you can deploy your template to Azure or AWS with a simple commit and no password stored in the service provider, this is so cool don't you think? No more chicken egg problem and even your devs are not aware of the secrets!

{% include important.html content="Keep it mind that people locally logged on the agent can fetch the secret value too, don't forget to roll all your secret once the maintenance is done." %}

# Graph API

Using ARC, we've seen a new service principal is now created, but without any App registration. In other words, we can't define which scope to request when we ask an access token for the graph API endpoint. Does it mean we're done? Let's see...

For this demo, we will simply create an AAD groups and add our serice principal owner on it. Let's create the AAD groups and don't forget to assign our SP as owner of the group:

![02](/assets/img/2021-02-20/02.png)

One created, take the ObjectId of our group. In my case, it's 906212d7-186d-4e30-ad65-9fdb3b1efad0. Then...

```powershell
#In the same console, let's generate a Graph token
$GraphToken = New-ARCAccessTokenMSI -Audience GraphAPI
#Let's create a variable with my group objectId
$GroupId = "906212d7-186d-4e30-ad65-9fdb3b1efad0"
# Create a broken Graph URI
$BrokenGrapURI = "https://graph.microsoft.com/v1.0/groups"
# Create a valid Graph URI
$WorkingGrapURI = "https://graph.microsoft.com/v1.0/groups/$GroupId"
# Call now graph API as usual with both working and broken URI
Invoke-RestMethod -ContentType 'application/json' -Headers @{'Authorization' = "Bearer $GraphToken"} -Uri $WorkingGrapURI
Invoke-RestMethod -ContentType 'application/json' -Headers @{'Authorization' = "Bearer $GraphToken"} -Uri $BrokenGrapURI

```

And as you can see, you can take action on objects you're owner! Something that I can't really understand is that even if I provide read group access to all my AAD groups to the SP, I can't use the $BrokenGraphURI which is weird. I've did it in the past with Az Function, but here it seems to be a current limitation.  

Anyway, it seems that you can now without any secret again, you can now implement IAC even to AAD objects (Groups, Enterprise App assignments, ...) which is super nice according to me. Let's try to remove our group for fun...

```powershell
Invoke-RestMethod -ContentType 'application/json' -Headers @{'Authorization' = "Bearer $GraphToken"} -Uri $WorkingGrapURI -Method delete

```

And it's done...

# Storage Account

Imagine now you need to interract with table, blobs or something else. Do you think we can interract from our local dev machine without any access keyx/ SAS token? Let's see!

For this demo, I've created a storage account (testarcfanf), a container (arc) and blob called hellofromarc.txt and then I've gave our MSI the RBAC data reader on this specific container.

```powershell
# Generate a new access token for storage audience
$StorageToken = New-ARCAccessTokenMSI -Audience StorageAccount
# Let's hardcode our blob URL
$blobURI = "https://testarcfanf.blob.core.windows.net/arc/hellofromarc.txt" #Use your value with your storage account/container/blob value
# Create our storage account header
$headers = @{
	'Authorization' = "Bearer $StorageToken"
	'x-ms-version' = "2020-04-08"
}
# let's access our blob file
Invoke-RestMethod -Uri $blobURI -Headers $headers -Method Get
#In my case, I will see
Hello from Azure ARC!

```

This is good news, we can access blob and I guess other types too from our MSI without access keys, SAS or password.

# Resource manager

With the previous demo, we have to target specific audiences, but what if we want to talk with ARM directly and use our well known Az Powershell module, let see how we can play with it!

For this demo, I've decided to grant my MSI reader access at the subscription level. Another thing we will need is to get the AppId of our Service Principal. You can decide to open the Enterprise Application tile or for fun, in [Graph Explorer](aka.ms/ge), you can use this query: https://graph.microsoft.com/v1.0/servicePrincipals?$filter=DisplayName eq '**<your computer name>**'&$select=Appid and grab it from there.

```powershell
# Define variables
$SubId = '<Your SubscriptionId>'
$AccountId = '<Your AppId (MSI Service Principal)>'

# Try to connect like we do usually in Azure
Connect-AzAccount -MSI 
#Generate an error. I guess it's because MS didn't include ARC in the equation yet. I hope it will come one day. 
#Instead let's generate a new access token, this time for ARM
$ARMToken = New-ARCAccessTokenMSI -Audience ARM

#Connect as an MSI using the AT instead
Connect-AzAccount -AccessToken $ARMToken -AccountId $AccountId -Subscription $SubId

#And you're in as your MSI! Let's now list our resource groups fro fun
$RGs = Invoke-AzRest -Path "/subscriptions/$SubId/resourcegroups?api-version=2020-06-01" -Method Get
# and here your RGs
$RGs.Content | ConvertFrom-Json | select -ExpandProperty value

# and is we prefer the regular Az commands, we can use instead this for the same result
Get-AzResourceGroup

```

Now it means that I can now from anywhere (not only Azure), doing automation, deploy resources, ...

{% include important.html content="One thing to keep in mind is that you don't receive any refresh token. You only have today an access token which means in other words the task you plan to do has to be done in the hour otherwise you may have authorization denies" %}

# Conclusion

During this article, we've just scratched the Azure ARC surface. But in this specific case, we can now do almost anything without any password, FOR FREE, which is awesome, thank you Microsoft for that.


**Here few take away** from this article:

- If you're ok with the idea to manage self agent, ARC for servers is a must have to improve your security posture if you're not in Azure. For a VM already hosted in Azure, it doesn't really make sense, just enabled the system managed identity instead.
- Now if you add a Keyvault, you can now deploy anything, anywhere without giniving any credentials to your devs. The only "weak" point is the person who has access to the machine which has to be tracked and monitored.
- ARC is not designed for workstations (Intune instead), but it's working well on my Win10. I have no idea if we can enable ARC for Linux client OS too.

Anyway, ARC seems super cool, and I've enjoyed playing with MSI on it. See you in the next one.

# References

[Azure ARC Overview](https://docs.microsoft.com/en-us/azure/azure-arc/)

[Jumpstart project](https://www.thomasmaurer.ch/2020/12/get-started-with-the-azure-arc-jumpstart/)

[425 Show](https://www.youtube.com/channel/UCIPMDupgTRsJY5sxcdBEtCg)
