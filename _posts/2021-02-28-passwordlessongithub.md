---
title: Concrete passwordless Github pipeline with ARC
date: 2021-02-28 00:00
categories: [identity,devops]
tags: [identity,Powershell,ARC,Devops]
---

# Introduction

previous article Theory now I want deploy a real test. Few month ago, I've played with AzDO, you can find my shift left researches [here](https://dev.azure.com/clt-100ba0e8-bfd0-402c-bcb5-c6dc4d62ba6c/LearnShiftLeft-pub) and i've wanted to do the same thing here but without password anywhere. The goal of this article will be to see how I've played with both Windows and Linux with Azure ARC to Verify/Deploy and tests my infrastructure.
As you can imagine, it's not production ready, but I've tried to include as much as concept as possible within this pipeline. So if you consider this pipeline is weird, this is normal :D.

To be able to be passwordless today, you have to use self-hosted agent. And if you're using self-hosted agent, it measn you does not want to use a public repo except if you kow what you're doing. I'm not a Github guru, I don't want someone clean my C drive, so I've decided to take the safe path and use a private repo connected to my self-hosted agents. You will be able to find a public copy of my private repo here --- public repo URL ----.

Here what we will build during this demo !

IMAGE HERE

Durgin this demo, we will:

- Play with Powershell 7:
  - We will use custom functions to get the access token or get a Keyvault secret
  - Use pester 5 module for the infrastructure tests
  - This demo won't work with Powershell 5
  - Use cross-platforms code. The same code will be used on both Linux and Windows self-hosted runners.
- User Gitleaks and Super-Linter to improve our code quality/security. I won't use Az SDK this time.
- Discover that [Azure CLI which is in front of almost everything compare to Az Powershell](https://scomnewbie.github.io/posts/clivspowershellaccesstoken/) sadly can't sign-ins with an access token. But I still want to use CLI compare to ARM template.

NOTE: I won't cover the basics, most of tasks are straight forward and well documented. Don't hesitate to ask if you have issue on something.

PRE REQUISITE KEYVAULT + secret CLI secretname -eq CLI APPId

# Windows Self-hosted agent

Here what I did to prepare my agent:
- Installed a fresh Windows server 2019
- Install the github self-hosted agent service as local admin, not NETWORK SERVICE. We actually need a local admin session to generate our access tokens. I don't think that NETWORK SERVICE can give us what we need.
- Install the ARC agent
- Install Powershell 7
- Create a profile.ps1 file located in the $PSHOME folder. Doing this the profile will load on all users. If you prefer you can create a profile in the local admin contet too.
- Fill the profile.ps1 with these 2 functions. First the [New-ARCAccessTokenMSI](https://github.com/SCOMnewbie/Azure/blob/master/Identity-AAD/New-ARCAccessTokenMSI.ps1) and then [Get-KeyvaultSecretValue](https://github.com/SCOMnewbie/Azure/blob/master/Identity-AAD/Get-KeyvaultSecret.ps1). Those 2 functions will help you to generate access tokens from the ARC agent to reach various audiences and the second one to simply access a secret from REST with the previously generated access token.
- Install the Az Powershell module
- Install the CLI binaries

Then open your RBAC Keyvault, go to your Azure CLI secret name (should be the AppId), and grant your self-runner ARC agent the Key Vault Secrets User permission.

At this point, we should be able to generate access token for the Keyvault audience from our ARC agent! Once you've done those actions, you should see in github you're agent in green:

![01](/assets/img/2021-02-28/01.png)

If you want to test, you can clone the repo and replace the values with yours in the settings.json file or in the generate-settings.ps1. Then before pushing this code to your private repo, make sure also that the WindowsSelfDeployment.yml is located under the .github/workflows folder. If not, simply copy/paste the one in the backup folder. You can now commit and push to Github which should start the pipeline.

IMPORTANT: Here I wanted to demo with Github because I have no skill with it, but you can do exactly the same thing with any other provider. The beauty of this demo is that you can run your runners anywhere and on any platforms. Same thing for the git repo, it can be your local Gitlab server. The only mandatory part is that your self-hosted require access to Azure and more specificaly Keyvault. In other words, you will need an Azure subscription if you want to deploy something in GCP.

Let's switch to the Linux agent. Then we will continue this demo.

# linux Self-hosted agent

Compared to my Windows agent which run locally on a hyper-V, I've decided to deploy my Linux agent in Azure.


# Explain the pipeline





# Conclusion

Blabla

**Here few take away** from this article:

- one.
- Two.


# References

[Fun with ARC](https://scomnewbie.github.io/posts/passwordlesswitharc/)

[Shift left with Azure DevOps](https://dev.azure.com/clt-100ba0e8-bfd0-402c-bcb5-c6dc4d62ba6c/LearnShiftLeft-pub)


