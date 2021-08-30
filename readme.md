# Azure AD Documents collection
This is a scenario based collection of documentaiton references with short descriptions for common scenarios asked by the customers.

While Azure AD documentation is well maintained and contains a lot of useful information, sometime the information you need to concrete scenario is scattered across with a lot cross links and references.

The idea behind this collection is to provide a structured information about concrete scenario, while referencing all relevant documentation.

## Customer scenarios

 * **Grant service principal limited Admin Consent permissions** - very often, in a cloud mature organization, it is necessary to automate the task of creating app registrations, service pricnipals, and sometimes even the Admin Consent.
 The provided scenario describes all of this with links and PowerShell snippets. Check this scenario [here](./RestrictedAdminConsent/readme.md).
 * **Configure SAML 2.0 Federation with KeyCloak** - step-by-step guide how to configure KeyCloak for SAML 2.0 Federation with Azure AD. Go to scenario's [readme.md](./FederationWithKeyCloak/readme.md).
  * **Custom synchronization** for custom federation. This short tutorial explains the core principles about user synchronization and the minimum information you should know, should you opt-in for developing your own user synchronization engine. Jump to [User Synchronization](./FederationWithKeyCloak/UserSync.md)