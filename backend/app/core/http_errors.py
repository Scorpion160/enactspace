"""Keep request-validation responses free of passwords, codes and raw input."""
from fastapi import Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

async def safe_validation_error(request: Request, exc: RequestValidationError):
    # Locations and error types support API clients without echoing credentials,
    # personal form values or exception contexts into an error response.
    errors = [
        {"field": ".".join(str(part) for part in error.get("loc", ())),
         "code": error.get("type", "invalid")}
        for error in exc.errors()
    ]
    return JSONResponse(
        status_code=422,
        content={"detail": "Vérifiez les informations saisies. Certains champs sont manquants ou invalides.",
                 "errors": errors},
    )
