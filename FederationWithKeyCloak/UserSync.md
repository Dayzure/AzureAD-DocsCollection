> **DISCLAIMER** The author / authors disclaim liability for any damages that arise from acting upon the information provided in this document. 

> **IMPORTANT** Information provided here concerns only basic Authentication and Federation scenarios with Azure AD and SAML 2.0 SP-Lite profile-based IdP. Information here does **not** cover any advanced authentication and authorization scenarios supported by Azure AD. Just as an example - Azure AD Join, or Hybrid Azure AD Join; device based conditional access policies; device management; enterprise state roaming; etc. There is absolutely no guarantee that anything beyond SAML 2.0 based authentication will work. Use at your own risk.

# User (and security groups) synchronization 

Part of every single sign-on solution is, of course, user provisioning. Before you can do anything with Azure AD, there must be a user object defined. Today, the only Microsoft supported way to synchronize users into Azure AD (from on-premises directories) is by the use of [Azure AD Connect](https://bit.ly/as-kc-fed-001) or [Azure AD Connect Cloud Provisioning](https://bit.ly/as-kc-fed-009).

When using custom federation with SAML 2.0, there is always the question - `do I have to use Azure AD Connect?`. And the answer is - `YES`. Becaue this is the only way, supported by Microsoft, to synchronize users and groups to Azure AD.

In this tutorial, we will learn what other _technical_ ways there are. 

> **NOTE** This article describes a not supported way to synchronize user objects from external sources (like on-premises Active Directory) to Azure AD. Use at your own risk and build an understanding of your own!

> **NOTE** The information provided here focuses on the process of `creating` user objects in Azure AD. It does **not** cover the process of `reading` users from `source system`. Neither on `quering delta` in source system. How do you query your source system of user identities, and how you keep track of synchronized changes, is entirely up to you.

## Identifying source anchor

The first and most important information about a synchronized user to identify the so called `source anchor` attribute. Please refer to [Azure AD Connect: Design Concepts](https://bit.ly/as-kc-fed-002), to understand in details about that concept. 
With regards to our [Use KeyCloak as SAML 2.0 Identity Provider for Single Sign-On with Azure AD](./readme.md) sample, we used all default settings. When you configure Azure AD Connect Sync with default settings, it uses the user's `ObjectGUID` as source anchor. Let's not forget that the GUID type is actually a binary type, so it's value is written in the form of `base64` encoded characters of the `bytes` of the GUID. This is important to remember, and to make difference between the base64 encoded *string* representation of a GUID vs. base64 representation of the actualy GUID bytes.

> **NOTE** Whatever value (user `attribute` in your source directory) you chose for the source anchor, you must make sure, you use the same user attribute for the `ImmutableID` attribute of your `SAML` assertions. Take a good decision, because you cannot change this value once you stamp it on a user object.

Again, as referenced in [Azure AD Connect: Design Concepts](https://bit.ly/as-kc-fed-002), the value of the source anchor is written to the `onPremisesImmutableId` property of the `User` resource in Microsoft Graph (ref.: [User Resource Type](https://bit.ly/as-kc-fed-011)). Important information about this property is that:
 * This user property can be `written` only `once`. Either when you create the user object, or when you convert the user object from managed to federated.
 * This poroperty can be read multiple times
 * Once set, this property cannot be changed (it is read only in that sense)
 * If you, for some reason, decide to change this value, you must delete and recreate the user object

## Creating the user object with identified source anchor

Once we are sure we know how to manage source anchor in our on-premises User store, we can proceed into creating users in Azure AD on our own.

> **NOTE** This tutorial assumes you already have working federated domain and you can successfully authenticate via KeyCloak. This means you have successfully completed steps in the [Use KeyCloak as SAML 2.0 Identity Provider for Single Sign-On with Azure AD](./readme.md) tutorial.

There are various way to create a `User` in Azure AD and point to an on-premises identity. 

### Create a user using Microsoft Graph REST API

The "raw" method of creating user is, of course, diretly write it to the REST API. You can refer to the [User Resource Type in Microsoft Graph](https://bit.ly/as-kc-fed-011) to understand that type and various operations. Most important for this tutorial is the `minimum` set of details you must provide in order to create a user within Azure AD, that will be authenticated by KeyCloak. You must provide the following properties (at least):

  * `accountEnabled` with a value of `true`
  * `displayName` - the display name for the user you are creating
  * `onPremisesImmutableId` - the most important one
  * `userPrincipalName` - UPN in the form of `username@federated.domain.com`. Where `federated.domain.com` is the FQDN of the domain you have configured for rederation with KeyCloak 
  * `mailNickname` - this property must have a value matching the UPN but withoung the `@` and the domain name. For example if the UPN is  `username@federated.domain.com`, then `mailNickname` should be `username`
  * `passwordPolicies` - with value of `DisablePasswordExpiration`

Thus a single `REST` call to Microsoft Graph to create a user will look like this:

```bash
curl --location --request POST 'https://graph.microsoft.com/v1.0/users' \
--header 'Content-Type: application/json' \
--header 'Authorization: Bearer eyxxx' \
--data-raw '{
            "accountEnabled": true,
            "displayName": "Username",
            "onPremisesImmutableId": "<the value you have chosen for source anchor>",
            "userPrincipalName": "username@federated.domain.com",
            "mailNickname": "username",
            "passwordPolicies": "DisablePasswordExpiration"
      }'
```

More information about the full list of properties and their meaning, you can read at [User Resource Type in Microsoft Graph](https://bit.ly/as-kc-fed-011)

Similarly you can also [Delete user via Microsoft Graph](https://bit.ly/as-kc-fed-012).

> **NOTE** Please make sure you do actually read the referenced Microsoft Graph documentation and understand what `permissions` are requried for one operation or the other. 

> *Information* You can read more about how to authentication your REST calls to Microsoft Graph on the official documentation page: [Authentication and authorization basics for Microsoft Graph](https://bit.ly/as-kc-fed-013)

### Create a user using Azure AD PowerShell for Microsoft Graph

You can also use [Azure AD PowerShell for Microsoft Graph](https://bit.ly/as-kc-fed-014) to manage user objects. This is Windows based PowerShell.

The command of most interes is [New-AzureADUser](https://bit.ly/as-kc-015) and this is the minimum set of properties (command parameters) you have to provide:

```PowerShell
$PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
$PasswordProfile.Password = "SomeStrong0rR@ndomPa5w0rD!"

New-AzureADUser `
    -AccountEnabled $true `
    -DisplayName 'PowerShell Created' `
    -UserPrincipalName 'posh.created@federated.domain.com' `
    -ImmutableId 'SomeBase64EncodedValue' `
    -MailNickName 'posh.created' `   
    -PasswordProfile $PasswordProfile

```

> **Note** This PowerShell command *requires* that you provide a password for the user account. You can generate cryptographically random string for this purpose.

### Create a user using Microsoft Graph Powershell with PowerShell Core 7.1

You must first install latest version of PowerShell Core. Just follow the instructions on the official site: [Install PowerShell Core on Linux](https://bit.ly/as-kc-fed-016).

Then you need to install PowerShell SDK for Microsoft Graph inside your PowerShell Core installtion. Check the PowerShell SDK for Microsoft Graph documentation: [Install MS Graph PowerShell SDK](https://bit.ly/as-msgraph-posh)

The following command will create a new user:

> *Information* the command bellow was executed on Ubuntu 18.04.5 LTS using PowerShell Core 7.1

```PowerShell
 New-MgUser -DisplayName "Mg SDK Created" `
    -UserPrincipalName "mg.created@federated.domain.com" `
    -MailNickname "mg.created" `
    -AccountEnabled -OnPremisesImmutableId "<the immutable id of choice>"
```

> **Note** Please make sure you understand the concepts of Microsoft Graph PowerShell SDK and how to authenticate, find command, use command. All that info can be found on the official page here: [Getting Started with PowerShell SDK for Microsoft Graph](https://bit.ly/as-mggraph-gettingstarted)

### Create a user using Azure cross platform CLI (command line interface)

You can also use Azure CLI to create user inside Azure AD. For more information on how to install Azure CLI on Linux refer to the following documentation [Install Azure CLI on Linux(apt)](https://bit.ly/as-az-cli)

Once you have Azure CLI installed and you have signed-in, you can perform the following command directly from Bash shell on Linux to create a new user (ref.: [az ad user](https://bit.ly/as-az-ad-user)):

```bash
az ad user create \
  --display-name "az created" \
  --password "rndP@55Wd!" \
  --user-principal-name "at.created@secninjas.eu" \
  --immutable-id "az.imm.id=="
```

# Conclusion

Technically, there are plenty of ways to manage user objects in Azure AD - from Azure AD PowerShell, over Microsoft Graph PowerShell SDK (using PowerShell Core) and Azure Cross Platform CLI to raw REST APIs. Once you choose the technology stack, make sure you dive deep in the relevant documentation.

> **Note** All referenced technologies (PowerShell, CLI, REST) **do** support `unattended` sign-in and you can script those and pack them im custom daemon process. The keyword to look for here is `service principal` authentication.

The summary presented here are anchors to help you get started!