# Restricted Admin Consent
When an organization mtures into the cloud, the question about how to manage [Admin Consent](https://bit.ly/as-adminconsent-01) delegations and even automate this, comes very often. In this short guidance we will learn how to delegate and automate Admin Consent to *fixed set* of predefined permissions. 

This example will use [Azure AD PowerShell Preview](https://bit.ly/as-adminconsent-02) module. This is required, because we will create a custom role with specific permissions. We will also make use of [App Consent Permissions Policy](https://bit.ly/as-adminconsent-03).

> **NOTE** Reading forward, please make sure you keep track and understand of `Application ID` vs `Object ID` in relation to `Application Registration` and `Service Principal` objects. It may be confusing, since in the scripts we sometime reference object id, sometimes application id. Make sure to read all referenced documentations and relevant PowerShell cmdlets documentation.

## Identify the list of permissions, you are willing to delegate the Admin Consent to
As a first step, you have to identify all the permissions, you would like to delegate the task of *Admin Consent* for. You can delegate Admin Consent for *any* permissions on *any* API registered in your tenant. Most importantly, you can delegate Admin Consent for both `Delegated` and `Application` permissions on `Microsoft Graph`. 

In the following example we want to delegate Admin Consent for the following permissions:

 * **Microsoft Graph** delegated permissions
  * The general *sign-in* type of permissions required for OpenID Connect sign-in and basic profile information: `openid`, `profile`, `email`, `offline_access`
  * `Mail.Read` - read the mail messages of the signed-in user
  * `Notes.Read` - read the OneNote notebooks of the signed-in user
  * `Files.Read` - list and read the OneDrive files of the signed-in user
* **Microsoft Graph** application permission
 * `PrintSettings.Read.All` - read Print settings for the organization without a signed-in user

To prepare the required list of permissions, we have to identify the Microsoft Graph's *service principal* object in our tenant. Then we need to find the object ids of required permissions for delegation. We use the following PowerShell snippt to achieve this:

```PowerShell
# Prepare permissions on MS Graph: 
# Note: the special GUID 00000003-0000-0000-c000-000000000000 is the application ID of Microsoft Graph
$graphSP = Get-AzureADServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"
$delegatedPermissions = @("openid","profile","email","offline_access", "Mail.Read", "Notes.Read", "Files.Read")
$graphDelegatedPermissions = @()
# loop over all delegated permissions MS Graph exposes
foreach($dp in $graphSP.Oauth2Permissions)
{
    if($dp.Value -in $delegatedPermissions)
    {
        $graphDelegatedPermissions += $dp.Id
    }
}

#loop over all application permissions (AppRoles) on MS Graph and look for "PrintSettings.Read.All"
$graphApplicationPermissions = @()
foreach($dp in $graphSP.AppRoles)
{
    if($dp.Value -eq "PrintSettings.Read.All")
    {
        $graphApplicationPermissions += $dp.Id
        break
    }
}
```

In addition, there is a registered API in our Azure AD tenant that exponses the following permissions:
* **resource-server-for-custom-permissions** *delegated* permissions ([image](./media/resource-server-delegated-permissions.jpg))
  * Data.ReadWrite (only administrators can consent)
  * Data.Read (Administrators and Users can consent)
* **resource-server-for-custom-permissions** *application* permissions ([image](./media/resource-server-application-permissions.jpg))
  * App.Data.ReadWrite (only administrators can consent)
  * App.Data.Read (only administrators can consent)

For the custom delegation, we want to delegate Admin consent to subset of **resource-server-for-custom-permissions**: the *delegated* `Data.ReadWrite` and the *application* permissions `App.Data.ReadWrite` and `App.Data.Read`.

For that, we use the following PowerShell snippet:

```PowerShell
# Prepare delegated and application pemrissions on custom app registration
# note, you need to work with the object id of the service principal for the application

# resource-server-for-custom-permissions
# Service Principal OID: 6d4aab75-3a8f-4281-8324-64a97e1960ed
# App ID: d730c5c8-a727-486d-a4e8-6c7a9f5b72f8
# Delegated Permissions: Data.ReadWrite (requires admin consent), Data.Read (user consent)
# Application Roles (assignable to apps)
# 2ddd3c93-a777-4aad-91b4-ba9c4081cc7f - App.Data.ReadWrite
# fdf9dda9-ebc2-407c-9cb7-d17ffd3a0def - App.Data.Read
$spObjectId = "6d4aab75-3a8f-4281-8324-64a97e1960ed"
$resourceSP = Get-AzureADServicePrincipal -ObjectId $spObjectId

# prepare delegated permissions for grants
# take only a delegated permission that requires Admin Consent, because it is more interesting
$resourceDelegatedPermissionsForGrants = @("Data.ReadWrite")
$resourceDelegatedPermissions = @()
foreach($dp in $resourceSP.Oauth2Permissions)
{
    if($dp.Value -in $resourceDelegatedPermissionsForGrants)
    {
        $resourceDelegatedPermissions += $dp.Id
    }
}

# prepare resource application permissions
# take all, as all application permissions require admin consent by default
$resourceApplicationPermissions = @()
foreach($dp in $resourceSP.AppRoles)
{
    $resourceApplicationPermissions += $dp.Id
}
```

Once we have identified the fiexed set of permissions for delegaitng Admin Consent, we have the following variables (lists) in our PowerShell script:

 * `$graphDelegatedPermissions` - a list of *delegated* permissions on Microsoft Graph
 * `$graphApplicationPermissions` - a list of *application* permissions on Microsoft Graph
 * `$resourceDelegatedPermissions` - a list of *delegated* permissions on custom API registered with our Azure AD Tenant
 * `$resourceApplicationPermissions` - a list of *application* permissions on custom API registered with our Azure AD Tenant

## Create a custom Applicaiton Consent Permission Policy 

Before we can create a custom Azure AD Administrator Role, we must define a custom application consent permissions policy. Before you dive deeper, or execute the next PowerShell snippets in your tenant, please take a time to read the official documentation about [App Consent Permissions Policy](https://bit.ly/as-adminconsent-03) and understand what we are doing this point forward.

Once we identified the required permissions, we can proceed with the step of creating that policy.

```PowerShell
# Create a policy
$policyId = "consent_g_d730c5c8-a727-486d-a4e8-6c7a9f5b72f8"
New-AzureADMSPermissionGrantPolicy `
    -Id $policyId `
    -DisplayName "Restricted consent grant policy for graph and d730c5c8-a727-486d-a4e8-6c7a9f5b72f8" `
    -Description "Capability to grant consent for delegated permissions to MS Graph and various permissions on service principal app id d730c5c8-a727-486d-a4e8-6c7a9f5b72f8"
```

There are couple of interesting points here:
 * `policyId` - the `ID` of the policy. This value is limited to 30 alphanumeric characters, including dashes and underscores.
 * `Display Name` - I tend to include at least information about granted permissions. In our case this is Microsoft Graph and a custom app with AppId `730c5c8-a727-486d-a4e8-6c7a9f5b72f8`
 * `Description` - in description you can be even more verbose.

Now let's add all the permissions we want to delegate. In our case we have four lists of permissions we want to use, so let's add them to the policy:

 ```PowerShell
 # include the MS Graph Delegated Permissions Grants
New-AzureADMSPermissionGrantConditionSet `
    -PolicyId $policyId `
    -ConditionSetType "includes" `
    -PermissionType "delegated" `
    -Permissions $graphDelegatedPermissions `
    -ResourceApplication $graphSP.AppId

# include the MS Graph Application Permissions Grants
New-AzureADMSPermissionGrantConditionSet `
    -PolicyId $policyId `
    -ConditionSetType "includes" `
    -PermissionType "application" `
    -Permissions $graphApplicationPermissions `
    -ResourceApplication $graphSP.AppId


# include the resource SP delegated permissions Grants
New-AzureADMSPermissionGrantConditionSet `
    -PolicyId $policyId `
    -ConditionSetType "includes" `
    -PermissionType "delegated" `
    -Permissions $resourceDelegatedPermissions `
    -ResourceApplication $resourceSP.AppId

# include the resource SP application permissions Grants
New-AzureADMSPermissionGrantConditionSet `
    -PolicyId $policyId `
    -ConditionSetType "includes" `
    -PermissionType "application" `
    -Permissions $resourceApplicationPermissions `
    -ResourceApplication $resourceSP.AppId

 ```

Now we have a new custom app consent policy in our tenant. This policy includes fixed set of permissions we want to delegate the process of Admin Consent for.

## Create a custom Azure AD Role that references ths custom app consent permissions grant policy

Coming to the last piece of informaiton we need - a custom role that reference the curtom app consent permission grant policy. Again, do not forget to carefully read through [App Consent Permissions Policy](https://bit.ly/as-adminconsent-03) to fully understand all pieces of the puzzle. 

Using the following PowerShell command, we create a custom Azure AD Administrative role, that is capable of granting admin consent for only fixed, predefined set of permissions:

```PowerShell
# Basic role information
$displayName = "CUSTOM RESTRICTED CONSENT ROLE"
$description = "Can consent Graph delegated permissions ('openid','profile','email','offline_access', 'Mail.Read', 'Notes.Read', 'Files.Read') plus all app permissions on appId (d730c5c8-a727-486d-a4e8-6c7a9f5b72f8) and the delegated permissions Data.ReadWrite "
$templateId = (New-Guid).Guid
 
# Set of permissions to grant
$allowedResourceAction =
@(
    "microsoft.directory/servicePrincipals/managePermissionGrantsForAll.$policyId"
)

$rolePermissions = @{'allowedResourceActions'= $allowedResourceAction}
 
# Create new custom admin role
New-AzureADMSRoleDefinition -RolePermissions $rolePermissions -DisplayName $displayName -Description $description -TemplateId $templateId -IsEnabled $true
```

By now you have noticed that I am very explicit in names and descriptions. 

## Stitching all together

All the referenced snippets are combined in a single PowerShell file for your reference: [CustomRestrictedConsentAdminRole.ps1](./CustomRestrictedConsentAdminRole.ps1).

The last and formal steps you have to perform are the following:
 * Create a new service principal (or use existing one) for your automation tasks
 * Give that service principal the `Application.ReadWrite.OwnedBy` *application* permission on **Microsoft Graph**. Having this permission, your service principal will be able to *create* and *update* another `application registrations` and `service principals`. Additionally it will be set as `owner` on the objects it creates. And it will not be able to see or manage *another* objects where it is not an `owner`. 
  > **NOTE** When granted `Application.ReadWrite.OwnedBy` role, all **objects** created by that service principal will count toward the 250 objects limit quota. For more information on quotas, please read [Azure AD service limits and restrictions](https://bit.ly/as-adminconsent-04)
 * Assign that service principal to the newly created custom role

> **NOTE** You should always wait some time (recommended at least 1 minute) between creating a custom role, assigning that role a service principal and getting a token for the service principal.

You can also can refer to [Manage App registrations and consents within Azure Active Directory](./ManageAppsAndConsents.md) document on how to issue admin consent using Microsoft Graph.