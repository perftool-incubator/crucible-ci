# GitHub Action Secrets

## Background

Crucible-CI uses GitHub Actions and some of those actions rely on secrets to provide authentication to external resources.  This file serves as documentation for the use, source, and formatting of those secrets.

## Quay

Crucible pushes and pulls images from repositories hosted on quay.io.  In order to push to these repositories an authentication token is required.  The quay login token that is needed looks like this (generically):

```json
{
    "auths": {
        "quay.io": {
            "auth": "<token here>",
            "email": ""
        }
    }
}
```

However, when saving this authentication token into the GitHub secret, it must be "escaped" so that it can be properly recreated by the reusable workflows that exist in this repository.  Thus, it should look like this:

```
{
    \"auths\": {
        \"quay.io\": {
            \"auth\": \"<token here>\",
            \"email\": \"\"
        }
    }
}
```
