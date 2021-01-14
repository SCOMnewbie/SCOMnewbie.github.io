---
title: First Attempt
date: 2021-01-12 00:00
categories: [TEST]
tags: [test]     # TAG names should always be lowercase
---

# This is the first article of this website

I'm used to mkdocs, let's see what we can do here.

## Hearders 2

Test images

![Desktop View](/assets/img/2021-01-12/01.png)

<span style="color:red">**Let's write something in red**</span>

<span style="color:green">Or in green</span>

# Let's add some code

```powershell

Write-host "This is a Write-host"
$var = Get-process
Write-output "Processes are: $($var)"

```

# Alerts

{% include note.html content="This is my note." %}

{% include tip.html content="This is my tip." %}

{% include warning.html content="This is my warning." %}

{% include important.html content="This is my important info." %}

# Labels

<span class="label label-default">Default</span>
