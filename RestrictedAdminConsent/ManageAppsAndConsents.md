# Manage App registrations and consents within Azure Active Directory
This document provides overview and direct links to the documentation parts describing each atomic operation. Because this document focuses on automation, meaning the use of service princal as the actor, all referenced required permissions are `Application` permissions on Microsoft Graph.

Before you begin, it is really important to understand the concept of [application and service principal objects](https://docs.microsoft.com/en-us/azure/active-directory/develop/app-objects-and-service-principals) in Azure AD. Please take your time to read that document first, before moving forward.

> **NOTE** This documentation describes explicitly how to create a custom role capable of granting admin consent to predefined set of permissions (both Microsoft Graph and any pre-existing app-registration permissions; both *delegated* and *application* permissions). This document does not explain *how to create app registration* itself. Please refer to [Manage App registrations within Azure Active Directory programatically](./ApplicationRegistration.md) document, to read more about how manage application registrations programatically.

## Authentication
Microsoft Graph is a REST API that implements ODATA protocol and is secured by OAuth authorization policy. For more information on how to obtain valid bearer token for use with Microsoft Graph check [this document](https://docs.microsoft.com/en-us/graph/auth-v2-service).

## Get a list of all application registrations for which the service principal is the owner

You can use the [List applications](https://docs.microsoft.com/en-us/graph/api/application-list?view=graph-rest-1.0&tabs=http) operation on MS Graph to get a list of app registrations. Sample call looks like following:

```bash
  curl --location --request GET 'https://graph.microsoft.com/v1.0/applications' \
  --header 'Authorization: Bearer xxx'
```

> The `least privilege` permissions that is needed to perform this action is `Application.Read.All` (being able to read *all* application registrations). Alternative permission is `Application.ReadWrite.OwnedBy`. A service principal granted `Application.ReadWrite.OwnedBy` will be able to read and modify application reigstrations and corresponding service principals, but only those where it is explicit `owner`. 

By default, when a service principal creates an object (application registration) using this permission, it is automatically added to the owner's collection.

## Create a new application registration

To create application registration you use the [Create application](https://docs.microsoft.com/en-us/graph/api/application-post-applications?view=graph-rest-1.0&tabs=http) operation on Microsoft Graph. 

> The least privileged permission is `Application.ReadWrite.OwnedBy`. 

Sample call to create application object looks like:

```bash
curl --location --request POST 'https://graph.microsoft.com/v1.0/applications' \
  --header 'Content-Type: application/json' \
  --header 'Authorization: Bearer xxx' \
  --data-raw '{
            "displayName": "Resource Server (WebAPI)",
            "signInAudience": "AzureADMyOrg",
            "identifierUris": ["https://idhero.de/apis/resource-server"],
            "api": {
                "requestedAccessTokenVersion": 2,
                "oauth2PermissionScopes": [
            	{
	                "adminConsentDescription": "Access Resource Server (WebAPI) as signed-in user",
	                "adminConsentDisplayName": "Access Resource Server (WebAPI) as signed-in user",
	                "id": "e69f58aa-48e6-4a1b-a714-7f13d1997213",
	                "isEnabled": true,
	                "type": "Admin",
	                "userConsentDescription": null,
	                "userConsentDisplayName": null,
	                "value": "user_impersonation"
            	}
        	]
            },
            "requiredResourceAccess": [
                {
                    "resourceAppId": "00000003-0000-0000-c000-000000000000",
                    "resourceAccess": [
                        {
                            "id": "37f7f235-527c-4136-accd-4a02d197296e",
                            "type": "Scope"
                        },
                        {
                            "id": "7427e0e9-2fba-42fe-b0c0-848c9e6a8182",
                            "type": "Scope"
                        }
                    ]
                }
            ],
            "web": {
                "redirectUris": [
                    "https://jwt.ms"
                ],
                "homePageUrl": null,
                "logoutUrl": null,
                "implicitGrantSettings": {
                    "enableIdTokenIssuance": true,
                    "enableAccessTokenIssuance": true
                }
            }
  }'
```
The meaning of some of the properties of the JSON paylod:

 * `signInAudience`: `AzureADMyOrg` means this application is only available to users in our enterprise directory
 * `identifierUris`: Unique Resource Identifier for our resource server. Must **not** be actual URL, but it has to be unique for our organization
 * `oauth2PermissionScopes`: (`Expose an API` in portal) an OAuth 2.0 *scope* (or scopes) that our resource exposes. Also known as *delegated* permission on the resource server. The `id` of each exposed scope, must be unique GUID
 * `requiredResourceAccess`: (`API Permissions`) in portal) declares required permissions. The listed from the example one are representing `openid` and `offline_access` *delegated* permissions on Microsoft Graph resource(`00000003-0000-0000-c000-000000000000`)

 > **NOTE** The single act of creating application registration does not create corresponding service principal. Neither are any permissions consented. To understand more about application and service principal objects, please refer to [this document](https://docs.microsoft.com/en-us/azure/active-directory/develop/app-objects-and-service-principals).

 ## Create a corresponding service principal object

 After we have created the application object, a service principal object must be created. Do not forget, that all actual authorization grants (consent, etc.) are applied on the service principal object.

 We use the [Create service principal](https://docs.microsoft.com/en-us/graph/api/serviceprincipal-post-serviceprincipals?view=graph-rest-1.0&tabs=http) operation. 
 
 > The least privileged permission is `Application.ReadWrite.OwnedBy`. 
 
 Sample request looks like:

 ```bash
 curl --location --request POST 'https://graph.microsoft.com/v1.0/servicePrincipals' \
  --header 'Content-Type: application/json' \
  --header 'Authorization: Bearer xxx' \
  --data-raw '{
    "appId": "22264534-4f93-4fef-8e12-6b311ac7c32a"
  }'
 ```

The only required information to create a service principal, is the `appId` (`Application (client) id` in portal) from the application object. Please note that this is not the `id` property of the application object, but the `appId` property of the same.  

> **NOTE** At this point we have an `application` object and its corresponding `service principal` object. No permissions have been granted so far. 

## Issue admin consent for delegated permissions
Issuing admin consent in Azure AD Tenant is a highly privileged operation and it's automation must be very carefuly considered. While one can automate this process, it would require granting very high privileges on Microsoft Graph for the service principal that will be executing the automation. 

I highly recommend a semi-automated process for issuing admin consent, where an actual administrator reviews the permissions and actively and knowingly issues the consent.

### Semi-automated process for delegated permissions
This process does not require any highly privileged permissions to be granted to the automation pricnipal. Once the `application` and `service principal` objects are created, all we need to do, is to compose a well known URL - the so call admin consent URL. We have to provide this URL to privileged administrator, who can review the required permissions and consent on behalf of the entire orgnaization. More information about the admin consent experience can be found [here](https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-admin-consent).
The admin consent URL looks like this:

```
  https://login.microsoftonline.com/{tenant}/v2.0/adminconsent
        ?client_id={appId}
        &scope=openid offline_access
        &redirect_uri=http://localhost/myapp/permissions
        &state=12345
```

Where
* `{tenant}` is the tenant identifier of the Azure AD directory. It may be the id (GUID) of the tenant, the `.onmicrosoft.com` domain, or any of the *verified* custom domains
* `{appId}` is the `Application (client) id` of the application registration. **Note** that this is **not** the `id` property of the application object in MS Graph.
* `scope` is a space separated list of scopes (*Delegated* Permissions) that we want to be granted. May icnlude `openid`, `offline_access` and *delegated* permissions to another resource.
* `redirect_url` must match a registered redirect URI for the client

Once we construct this URL, it can be used in any manual gate process where the action required from an administrator will be limited to reviewing the permissions and click on `Accept` button.

### Fully automated process for censting to delegated permissions
To grant delegated permissions, we can use the [Create delegated permissions grant (oauth2PermissionGrant)](https://docs.microsoft.com/en-us/graph/api/oAuth2permissiongrant-post?view=graph-rest-1.0&tabs=http).

> The least privileged Microsoft Graph *application* permission to perform this operation is `Directory.ReadWrite.All`. This permission, however, grants read/write access to the entire directory.

> Alternative, you can grant the automation service principal the [Cloud Application Administrator](https://docs.microsoft.com/en-us/azure/active-directory/roles/permissions-reference#cloud-application-administrator) role in the Directory. Thus, you are limiting the actual permissions, because `Cloud application administrator` has less privileges then the *application* permissions `Directory.ReadWrite.All`

Chosing what privileges to grant the automation service principal is to find balance between [Directory.ReadWrite.All](https://docs.microsoft.com/en-us/graph/permissions-reference#directory-permissions) and [Cloud Application Administrator](https://docs.microsoft.com/en-us/azure/active-directory/roles/permissions-reference#cloud-application-administrator)

Sample request to issue admin consent for delegated permissions would look like:

```bash
  curl --location --request POST 'https://graph.microsoft.com/v1.0/oauth2PermissionGrants' \
    --header 'Content-Type: application/json' \
    --header 'Authorization: Bearer xxx' \
    --data-raw '{
        "clientId": "70ef4b84-e8eb-4d33-9d25-19bc408c108d",
        "consentType": "AllPrincipals",
        "resourceId": "2f5da732-9f8c-4fc8-af76-64fe375fb354",
        "scope": "openid offline_access"
    }'
```

Where

 * `clientId` - **!! Note** this is the **object id** of the `service principal` representing the `app registration` which requires access to other APIs (`API Permissions` in portal)
 * `consentType` - `AllPrincipals` means this will be an admin consent for the entire organization
 * `resourceId` - this must be the `object id` (`id` property of the object in MS Graph) of the `service principal` that **exposes** *delegated* permissions. In our sample, we are granting `openid` and `offline_access` delegated permissions on Microsoft Graph. Thus the `resourceId` in this call will be the `object id` of the Microsoft Graph service principal in our directory. To find out the MS Graph service princpal in our directory, we have to look in the Azure AD Portal -> Enterprise Applications -> change filters to `All applications`, `Any`, `Any` and finally type in the search box the well known app id for MS Graph (`00000003-0000-0000-c000-000000000000`). Alternatively you can use the following Azure AD PowerShell command to retrieve the `service principal` representing Microsoft Graph in your tenant:
 ```PowerShell
  Get-AzureADServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"
 ```
 * `scope` is the list of scopes we want to grant admin consent for

 Detailed information about this API is located [here](https://docs.microsoft.com/en-us/graph/api/oAuth2permissiongrant-post?view=graph-rest-1.0&tabs=http).

 ## Issue admin consent for *application* permissions

 Application permissions are always to be evaluated very carefully. That is because, in order to use this type of permission, an application (or daemon, or malicious actor) does not need to have active end user session. An *application* permission is granted to the `service principal` identity. This is also why, it is so important to have strict control on how you manage service principal identities in your organization. Do you use application secrets (symmetric keys)? How do you rotate them? How long living are they? Or do you use [certificate credentials](https://docs.microsoft.com/en-us/azure/active-directory/develop/active-directory-certificate-credentials) for your service pricnipals?

 More thoughts around securing service principals and different types of service principals and authentication method can be read [here](https://docs.microsoft.com/en-us/azure/active-directory/fundamentals/service-accounts-introduction-azure).

 *Application* permissions are exposed by an application registration in the form of [application *roles*](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-add-app-roles-in-azure-ad-apps). When we want to grant another entity access to this *application* role, we must first know the actual `id` of the role itself. In order to grant service principal access to applicaiton role, the role must indicate that it allows *applications* to be assigned.

 The process of admin consent to application permissions is represented as [appRoleAssignment](https://docs.microsoft.com/en-us/graph/api/serviceprincipal-post-approleassignedto?view=graph-rest-1.0&tabs=http) in Microsoft Graph. Sample call to MS Graph to grant admin consent for particular application role would be:

 ```bash
 curl --location --request POST 'https://graph.microsoft.com/v1.0/servicePrincipals/{sp-object-id}/appRoleAssignments' \
--header 'Content-Type: application/json' \
--header 'Authorization: Bearer xxx' \
--data-raw '{
  "principalId": "{sp-object-id}",
  "resourceId": "102d1537-0cc6-41c4-94ba-21ef5b0520bc",
  "appRoleId": "bdca3e92-4051-4cd1-a4f0-6d8b0d521b5f"
}'
 ```

 Where
  * `{sp-object-id}` from the request path is the object id of the service principal that will be granted an application role (application permission)
  * `principalId` - will have same value as the object id in the URL path of the request. Again, representing the service principal that is being granted an application role
  * `resourceId` - the **object id** of the **service principal** that exposes an application role. Remember, that application roles where defined on the application object. But the authorizations/grants happen on the service principal object. So, here, you need a service principal object id.
  * `appRoleId` - this is the `id` of the application role. You can take this value from the application manifest.

  > **NOTE** the least privileged permission to perform this operation is `AppRoleAssignment.ReadWrite.All` and `Application.Read.All` - both!

  > **NOTE** alternative, [Cloud Application Administrator](https://docs.microsoft.com/en-us/azure/active-directory/roles/permissions-reference#cloud-application-administrator) role is also capable of grant application permissions that do **not** include **Microsoft Graph**.
