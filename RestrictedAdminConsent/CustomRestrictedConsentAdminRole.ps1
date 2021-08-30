Connect-AzureAD

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

# Prepare delegated pemrissions on custom app registration
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

# Create a policy
$policyId = "consent_g_d730c5c8-a727-486d-a4e8-6c7a9f5b72f8"
New-AzureADMSPermissionGrantPolicy `
    -Id $policyId `
    -DisplayName "Restricted consent grant policy for graph and d730c5c8-a727-486d-a4e8-6c7a9f5b72f8" `
    -Description "Capability to grant consent for delegated permissions to MS Graph and various permissions on service principal app id d730c5c8-a727-486d-a4e8-6c7a9f5b72f8"


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

# Basic role information
$displayName = "CUSTOM RESTRICTED CONSENT ROLE"
$description = "Can consent Graph delegated permissions ('openid','profile','email','offline_access', 'Mail.Read', 'Notes.Read', 'Files.Read') plus all app permissions on appId (d730c5c8-a727-486d-a4e8-6c7a9f5b72f8) and the delegated permissions Data.ReadWrite "
# Generate a new random GUID to be used as role template id
$templateId = (New-Guid).Guid
 
# Set of permissions to grant
$allowedResourceAction =
@(
    "microsoft.directory/servicePrincipals/managePermissionGrantsForAll.$policyId"
)

$rolePermissions = @{'allowedResourceActions'= $allowedResourceAction}
 
# Create new custom admin role
New-AzureADMSRoleDefinition `
  -RolePermissions $rolePermissions `
  -DisplayName $displayName `
  -Description $description `
  -TemplateId $templateId `
  -IsEnabled $true
