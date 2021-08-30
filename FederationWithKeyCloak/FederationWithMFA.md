# General thoughts and sources of information

As you may already discovered, Microsoft only supports the combination of Azure AD Connect (for user synchronization) plus Active Directory Federation Services (ADFS) (for federated authentiction) for hybrid identity scenarios. While, there is also support for third party Identity Providers / STS, this is only limited to the generic support of SAML 2.0 SP-Lite profile-based protocol for federation, as described in this article. 

So, once you configured you SAML 2.0 IdP, you would also want to make sure that Azure AD understands your IdP can also do MFA and respect this. The documentation on the subject is limited, that's why here is a step-by