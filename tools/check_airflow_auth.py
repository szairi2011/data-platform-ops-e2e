import urllib.request, json

with urllib.request.urlopen("http://localhost:8080/openapi.json") as r:
    spec = json.load(r)

# Check security schemes
print("Security schemes:")
print(json.dumps(spec.get("components", {}).get("securitySchemes", {}), indent=2))

# Check global security
print("\nGlobal security:", spec.get("security", "none"))

