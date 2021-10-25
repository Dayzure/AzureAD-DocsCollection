# Manage App registrations within Azure Active Directory programatically
This collection of snippets and short descriptions focuses on the application registration lifecycle management using fully automated approach. Samples provided are using Microsoft Graph directly, or Azure AD PowerShell (for where a PowerShell module / commandlet is abailable).

# Before we begin
Before we begin it is important to remember what is an [application registration in Azure AD](https://bit.ly/3jxGeM3), what are [API Permissions](https://bit.ly/3pwwwgH), [Application Roles](https://bit.ly/2Scu4d9), [Scopes](https://bit.ly/3BnnqoV). Last but not least, important subject to understand is also the [application and service principal objects in Azure AD](https://bit.ly/3m8uf9m). It is also important to understand the difference between *delegated* permissions and *application* permissions, as described [in this documentation](https://bit.ly/3nnkUtH).

When we talk about automation, this usually means there is no user involved. All operations must be executed from a properly authorized account. Such account is called *service principal* in Azure Avtive Directory. And in order to actually successfully create or modify application reigstration objects, our service account must be *granted* (at least) the following **application** permission on Microsoft Graph - `Application.ReadWrite.OwnedBy`. This effectively gives permissions to create new application (and service principal) objects *as owner*. And to read and modify all application (and service principal) objects, where our automation account is added as owner.

# Create an application registration
After we resembled what is an application registration, permissions, scopes, roles, let's now create our first application registration programatically. But before we can actually create an app registration, we need to collect some information. Let's assume we have collected the following basic information about our application registration. We will be create a new Web API application and will be exposing some scopes (for *delegated* permissions). 

## Basic application registration information
We collect the following information about our Web API application registration:

 * Application identifier (`Application ID URI`): `https://contoso.com/apis/books` 
 > **Note** An application identifier is just an URI (Uniform Resource Identifier) and does not have to represent the real URL (Uniform Resource Locator). There are verious patterns you can use for your application id uri, but it has to be uniquie (at best globally unique). However, if you choose to use `HTTPS` scheme for `application uri identifier`, you have to use a **verified** domain (in that case `contoso.com` is a *verified* domain in current directory). You can use the following schemes for application identifier: `HTTPS`, `API` (e.g. api://some-identifier), `URN` (e.g. URN:CONTOSO:APIS:BOOKS) or `MS-APPX`.

 * Reply URL for Web API Platform: (empty). when we expose real REST API Service, we do not actually need to have any reply url configured in Azure AD. That is, because a REST API is not supposed to execute any interactive sign-in/authorization flows. 
 * Disaply Name: `Contoso Books API`
 * Account types to sign in: Accounts in current organization directory only (single tenant)
 * Exposed APIs:
   * `Books.Read` (Users and Admins can grant consent) - we **must** generate a new GUID as `id` for this scope
   * `Books.ReadWrite` (only Admins can grant consent) - we **must** generate a new GUID as `id` for this scope
  
Exposing an API Scopes is represented within the `oauth2PermissionScopes` collection of the  `api` section of `application manifest` (or the JSON payload of `create` application registration operation):

```json
"api": {
    "requestedAccessTokenVersion": 2,
    "oauth2PermissionScopes": [
      {
          "adminConsentDescription": "Read books of the signed-in user",
          "adminConsentDisplayName": "Books.Read",
          "id": "<GENERATED-GUID-FOR-THIS-SCOPE>",
          "isEnabled": true,
          "type": "User",
          "userConsentDescription": "Read your books",
          "userConsentDisplayName": "Read your books",
          "value": "Books.Read"
      },
      {
          "adminConsentDescription": "Read and Write the books of the signed-in user",
          "adminConsentDisplayName": "Books.ReadWrite",
          "id": "<GENERATED-GUID-FOR-THIS-SCOPE>",
          "isEnabled": true,
          "type": "Admin",
          "userConsentDescription": null,
          "userConsentDisplayName": null,
          "value": "Books.ReadWrite"
      }
    ]
}
```

## Required API permissions
When we have a micro services environment, usually services need to communicate between each other (in a secure manner). To do so, a proper configuration is required on application registration. Let's assume, the Books API we are developing, needs to check books inventory that is served by another REST API (`Books Inventory`). The book inventory API is already a registered application in Azure AD and exposes scopes (*delegated* permissions - `user_impersonation`) and application roles (*application* permissions - `Inventory.Read`, `Inventory.ReadWrite`). 
In order to, programatically, add any of these permissions to our new app registration we need to find out several key properties of the `Book Inventory` application registration:

 * `Application (client) id` - this is the **application id** (**not** object id) of the application registration of `Books Inventory`. To avoid any confusion, we will use a placeholder `{BooksInventory-AppId}` in our code samples
 * `id` of the *scope* `user_impersonation` that is exposed on the *Books Inventory* app. This is a `GUID`. Again, to avoid confusion we use a placeholder: `{BooksInventory-UserInpersonation-Scope-GUID}`
 * `id` of the *application role* `Inventory.Read`. Placeholder: `{BooksInventory-Role-GUID}`

 ### Microsoft Graph delegated permissions
 Our Books API have a functionality that integrated with Microsoft Office One Note and requires a *delegated* permission on Microsoft Graph to read signed-in user's OneNote notebooks (ref. [MS Graph Notes Read](https://bit.ly/3b9HnF0)). To add this Microsoft Graph *delegated* permission to the list of requried permissions for our new Application registration, we have to find out its `id`. To do so, we use Azure AD PowerShell and the following snippet:

```PowerShell
# Note: the special GUID 00000003-0000-0000-c000-000000000000 is the application ID of Microsoft Graph
$graphSP = Get-AzureADServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"
$delegatedPermissions = @("Notes.Read")
$graphDelegatedPermissions = @()
# loop over all delegated permissions MS Graph exposes
foreach($dp in $graphSP.Oauth2Permissions)
{
    if($dp.Value -in $delegatedPermissions)
    {
        Write-Output $dp.Id
    }
}
```
We take a note on this `id` (placeholder `{MS-Graph-Notes.Read-Scope-GUID}`).

## Create the application registration object using MS Graph Directly

You can use the Microsoft Graph REST API directly to create an application registration. This is a sample `HTTP POST` requirest to create the described Books API app registration:

```bash
curl --location --request POST 'https://graph.microsoft.com/v1.0/applications' \
--header 'Content-Type: application/json' \
--header 'Authorization: Bearer <jwt_token>' \
--data-raw '{
            "displayName": "Contoso Books API",
            "signInAudience": "AzureADMyOrg",
            "identifierUris": ["https://contoso.com/apis/books"],
            "appRoles": [],
            "api": {
                "requestedAccessTokenVersion": 2,
                "oauth2PermissionScopes": [
                  {
                      "adminConsentDescription": "Read books of the signed-in user",
                      "adminConsentDisplayName": "Read books of the signed-in user",
                      "id": "<GENERATED-GUID-FOR-THIS-SCOPE>",
                      "isEnabled": true,
                      "type": "User",
                      "userConsentDescription": "Read books your books",
                      "userConsentDisplayName": "Read books your books",
                      "value": "Books.Read"
                  },
                  {
                      "adminConsentDescription": "Read and Write the books of the signed-in user",
                      "adminConsentDisplayName": "Read and Write the books of the signed-in user",
                      "id": "<GENERATED-GUID-FOR-THIS-SCOPE>",
                      "isEnabled": true,
                      "type": "Admin",
                      "userConsentDescription": null,
                      "userConsentDisplayName": null,
                      "value": "Books.ReadWrite"
                  }
        	      ]
            },
            "requiredResourceAccess": [
                {
                    "resourceAppId": "00000003-0000-0000-c000-000000000000",
                    "resourceAccess": [
                        {
                            "id": "{MS-Graph-Notes.Read-Scope-GUID}",
                            "type": "Scope"
                        }
                    ]
                },
                 {
                    "resourceAppId": "{BooksInventory-AppId}",
                    "resourceAccess": [
                        {
                            "id": "{BooksInventory-UserInpersonation-Scope-GUID}",
                            "type": "Scope"
                        },
                        {
                            "id": "{BooksInventory-Role-GUID}",
                            "type": "Role"
                        }
                    ]
                }
            ]
}'
```

## Create the application registration object using Azure AD PowerShell

The following PowerShell snippet creates an app registration with the above agreed properties:

```PowerShell
Connect-AzureAD

## Well-Known variables with values
$MsGraphAppId = "00000003-0000-0000-c000-000000000000"
## Variables, fill in pre-collected values
$MsGraphScopeGUID = "{MS-Graph-Notes.Read-Scope-GUID}"
$BooksInventoryAppId = "{BooksInventory-AppId}"
$BooksInventoryScopeID = "{BooksInventory-UserInpersonation-Scope-GUID}"
$BooksInventoryRoleID = "{BooksInventory-Role-GUID}"

$AppDisplayName = "Books API"
$AppIdUri = "https://idhero.de/apis/books"

$BooksReadScopeId = [guid]::NewGuid()
$BooksReadWriteScopeId = [guid]::NewGuid()

$booksReadPermission = New-Object -TypeNAme "Microsoft.Open.AzureAD.Model.OAuth2Permission"
$booksReadPermission.Id = $BooksReadScopeId
$booksReadPermission.Type = "User"
$booksReadPermission.Value = "Books.Read"
$booksReadPermission.AdminConsentDisplayName = "Books.Read"
$booksReadPermission.AdminConsentDescription = "Read books of the signed-in user"
$booksReadPermission.UserConsentDisplayName = "Books.Read"
$booksReadPermission.UserConsentDescription = "Read your books"

$booksReadWritrePermission = New-Object -TypeNAme "Microsoft.Open.AzureAD.Model.OAuth2Permission"
$booksReadWritrePermission.Id = $BooksReadWriteScopeId
$booksReadWritrePermission.Type = "User"
$booksReadWritrePermission.Value = "Books.ReadWrite"
$booksReadWritrePermission.AdminConsentDisplayName = "Books.ReadWrite"
$booksReadWritrePermission.AdminConsentDescription = "Read and write books of the signed-in user"

## Define the exposed Scopes


## Define the required resource access for your new application object
$GraphResourceAccess = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess"
$GraphResourceAccess.Id = $MsGraphScopeGUID
$GraphResourceAccess.Type = "Scope"
$GraphRequiredResourceAccess = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess"
# well known GUID of Microsoft Graph Application Id
$GraphRequiredResourceAccess.ResourceAppId = $MsGraphAppId
$GraphRequiredResourceAccess.ResourceAccess = $GraphResourceAccess

## Defined the required access for BooksInventory AppId
# define the required SCOPE
$BooksInventoryScope = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess"
$BooksInventoryScope.Id = $BooksInventoryScopeID
$BooksInventoryScope.Type = "Scope"

# define the required ROLE (application permission)
$BooksInventoryRole = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess"
$BooksInventoryRole.Id = $BooksInventoryRoleID
$BooksInventoryRole.Type = "Role"

$BooksInventoryRoleRequiredResourceAccess = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess"
# well known GUID of Microsoft Graph Application Id
$BooksInventoryRoleRequiredResourceAccess.ResourceAppId = $BooksInventoryAppId
$BooksInventoryRoleRequiredResourceAccess.ResourceAccess = @($BooksInventoryScope, $BooksInventoryRole)

$app = New-AzureADApplication `
 -DisplayName $AppDisplayName `
 -IdentifierUris $AppIdUri `
 -Oauth2Permissions @($booksReadPermission, $booksReadWritrePermission) `
 -RequiredResourceAccess @($GraphRequiredResourceAccess, $BooksInventoryRoleRequiredResourceAccess)

$app
```

# Create Service Principal

The refenrece to [application and service principal objects in Azure AD](https://bit.ly/3m8uf9m) documentaion is not accidental. It is very important to understand the relationship between these objects and what each of them represent. That said - if you create application registration in Azure Portal, a service principal object is automatically created in the background. However, when you create application reigstration programatically, there is no service principal created. In order to have fully functional deployment, we need to also create a service principal object.

Luckily for us, creating service principal object is fairly simple and stright forward operation. The required Mirosoft Graph permissions, that allow for creation of service principals is, again, `Application.ReadWrite.OwnedBy`.

There is only one required variable when we create a service principal - namely the `application/client id` of the registered application. This value is given back directly  when we create the application registration (either using MS Graph or Azure AD PowerShell). Again, we use placeholder - `{BooksApi-AppId}`. Again, this value is returned by the Microsoft Graph (`appId`) or PowerShell (`AppId`) when we create the application registration

## Create Service Principal using Microsoft Graph

To create a service principal using Mirosoft Graph follow the [Service Principal create](https://bit.ly/2ZmnhEw) operation:

```bash
curl --location --request POST 'https://graph.microsoft.com/v1.0/servicePrincipals' \
--header 'Content-Type: application/json' \
--header 'Authorization: Bearer <jwt_token>' \
--data-raw '{
  "appId": "{BooksApi-AppId}"
}'
```

## Create Service Principal using PowerShell

To create a service principal using Azure AD PowerShell follow the [New-AzureADServicePrincipal](https://bit.ly/30ZZo6P) command:

```PowerShell
$appId = "{BooksApi-AppId}"
New-AzureADServicePrincipal -AppId $appId
```

# Summary
In this document we revealed how to create an application reigstration and corresponding service principal. It also describes how to expose `Scopes` for the new application registration, and how to add `Required API Access` (to Microsoft Graph and to pre-existing application registration, both *delegated* and *application* permissions).

The process of granting Admin consent is not covered in this document.