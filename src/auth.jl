using PyCall
using PyCallUtils
using JSON3

pyimport_Credentials() = pyimport_object("google.oauth2.credentials", "google-auth", :Credentials)
pyimport_Request() = pyimport_object("google.auth.transport.requests", "google-auth", :Request)
pyimport_InstalledAppFlow() = pyimport_object("google_auth_oauthlib.flow", "google-auth-oauthlib", :InstalledAppFlow)
pyimport_build() = pyimport_object("googleapiclient.discovery", "google-api-python-client", :build)

function auth(secretpath, tokenpath, scopes)
    if isfile(tokenpath)
        Credentials = pyimport_Credentials()
        credentials = Credentials.from_authorized_user_file(tokenpath, scopes)::PyObject
        secretjson = JSON3.read(read(secretpath))
        if credentials.client_id::String == secretjson.installed.client_id::String
            if credentials.valid::Bool
                if credentials.expired::Bool && !isnothing(credentials.refresh_token::Union{Nothing,String})
                    Request = pyimport_Request()
                    credentials.refresh(Request())
                end
            end
            return credentials
        end
    end
    InstalledAppFlow = pyimport_InstalledAppFlow()
    flow = InstalledAppFlow.from_client_secrets_file(secretpath, scopes)::PyObject
    return flow.run_local_server(port=0)::PyObject
end
"""
    build_service(secretpath, tokenpath, scopes, name, version)

```
secretpath = "client_secret.json"
tokenpath = "token.json"
scopes = ["https://www.googleapis.com/auth/youtube.force-ssl"]
name = "youtube"
version = "v3"
build_service(secretpath, tokenpath, scopes, name, version)
```
"""
function build_service(secretpath, tokenpath, scopes, name, version)
    credentials = auth(secretpath, tokenpath, scopes)
    open(tokenpath, "w") do io
        write(io, credentials.to_json())
    end
    build = pyimport_build()
    build(name, version; credentials)::PyObject
end
function build_service(secretpath, scopes, name, version)
    tokenpath = create_tokenpath(secretpath)
    build_service(secretpath, tokenpath, scopes, name, version)
end
function create_tokenpath(secretpath)
    secretjson = JSON3.read(read(secretpath))
    tokenfile = "token_$(secretjson.installed.client_id::String).json"
    joinpath(splitdir(secretpath)[1], tokenfile)
end

"""
    google_error_reasons(e)
"""
function google_error_reasons(e)
    reasons = String[]
    try
        json = JSON3.read(e.val.content)
        for error in json.error.errors
            push!(reasons, error.reason)
        end
    catch
    end
    reasons
end