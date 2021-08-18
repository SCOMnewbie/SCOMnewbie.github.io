---
title: Use Graph API batching to speed things up? 
date: 2021-08-19 00:00
categories: [powershell]
tags: [graphAPI, Powershell]
---

# Introduction

Lately I had to find a way to populate few office365 groups dynamically based on an enterprise application users & groups assignment to generate dynamic email lists. Long story short, we’re using the enterprise application as a provisioning tool to grant access to an external application. Check the [documentation](https://docs.microsoft.com/en-us/azure/active-directory/app-provisioning/configure-automatic-user-provisioning-portal) for more details. The plan was simple originally. We list the groups assigned to the enterprise app (I don’t have direct user assignment in this case), and then for each group, we list the members, to finally merge everything with a select -unique at the end. Of course, the plan has changed when I’ve discovered that for few enterprise applications I had more than **3000 groups assigned to it** …

In this article, I will focus on how I’ve used [batching with graph API](https://docs.microsoft.com/en-us/graph/json-batching) **to reduce the execution time from 14 min to less than 1 minute and 20 seconds**.

{% include note.html content="Initially, I had to populate Exchange distribution lists (and security group with mail enabled) instead of Office365 groups, but I’ve discovered that only Global Admins can modify group membership through graph. A regular user can’t, even if he owns the group." %}

If you're interested, you can find a [demo code here](https://github.com/SCOMnewbie/Azure/blob/master/GraphAPI/Batch/README.md).

# Original plan

## List the Enterprise app asignment

Here the most important line, /servicePrincipal is to query Enterprise applications where /application is for App registration.

``` Powershel

"/servicePrincipals/<Enterprise app objectId>/appRoleAssignedTo?`$top=999&`$select=principalId"

```

This will give us the first 999 elements (groups in my case) assigned to this specific enterprise app. With more than 3k groups, we must deal with paging.  I’m using the Get-AADAppRoleAssignedTo function as helper. You can find it in the [loadme module](https://github.com/SCOMnewbie/Azure/blob/master/GraphAPI/Batch/loadme.psm1).

## List group membership

Now we have all groups, we just have to flat everything and add the result into an array. Here the main line again:

``` Powershel

"/groups/<group principalId >/members?`$top=99"

```

If we have more than 99 members per group, we will have to manage paging again then store the result in a big array. This is the bad part, because we will have to call Graph API more than 3000 times in our case. The basic 3000 calls because of the number of groups and more if you have more than 99 users in some of them. In my case this part takes between 12 and 14 minutes.

## Filter to remove duplicates

Now that we have an array full of duplicates, let's simply clean it with:

``` Powershel

$FinalResult = $BigQueryResults | Select-Object userPrincipalName,Id -Unique

```


![appsettings](/assets/img/2021-07-28/appsettings.png)