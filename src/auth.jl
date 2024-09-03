using PythonCall, CondaPkg
#]conda add google-auth google-auth-oauthlib google-auth-httplib2 google-api-python-client
using JSON3

function auth(secretpath, tokenpath, scopes)
    if isfile(tokenpath)
        Credentials = pyimport("google.oauth2.credentials").Credentials
        credentials = Credentials.from_authorized_user_file(tokenpath, scopes |> pylist)
        secretjson = JSON3.read(read(secretpath))
        if string(credentials.client_id::Py) == secretjson.installed.client_id::String
            if pynot(credentials.valid)
                if pytruth(credentials.expired) && pytruth(credentials.refresh_token)
                    Request = pyimport("google.auth.transport.requests").Request
                    credentials.refresh(Request())
                end
            end
            return credentials
        end
    end
    InstalledAppFlow = pyimport("google_auth_oauthlib.flow").InstalledAppFlow
    flow = InstalledAppFlow.from_client_secrets_file(secretpath, scopes |> pylist)
    return flow.run_local_server(port=0)
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
        write(io, credentials.to_json() |> string)
    end
    build = pyimport("googleapiclient.discovery").build
    build(name, version; credentials)
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