# Keep Product Integrations in the Build Framework repository

The Build Framework, Platform Integrations, and Product Integrations will remain in one repository rather than being split into separate product repositories. Product-specific content must be owned by a top-level `products/<product>/` boundary, while `platforms/<vendor>/` remains product-agnostic; this favors one checkout and atomic framework-to-product changes at the cost of requiring strict ownership and CI rules to prevent product policy from leaking back into the framework.
