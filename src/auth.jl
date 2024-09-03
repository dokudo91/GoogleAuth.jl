using PythonCall, CondaPkg
#]conda add google-auth google-auth-oauthlib google-auth-httplib2 google-api-python-client
using JSON3

const Credentials = pyimport("google.oauth2.credentials").Credentials
const InstalledAppFlow = pyimport("google_auth_oauthlib.flow").InstalledAppFlow
const Request = pyimport("google.auth.transport.requests").Request
const build = pyimport("googleapiclient.discovery").build

function auth(secret, scopes)
    flow = InstalledAppFlow.from_client_secrets_file(secret, scopes |> pylist)
    flow.run_local_server(port=0)
end
"""
    build_service(secretpath, tokenpath, scopes, name, version)
"""
function build_service(secretpath, tokenpath, scopes, name, version)
    secretjson = JSON3.read(read(secretpath))
    if isfile(tokenpath)
        credentials = Credentials.from_authorized_user_file(tokenpath, scopes |> pylist)
        if credentials.client_id |> string == secretjson.installed.client_id
            if pynot(credentials.valid)
                if pytruth(credentials.expired) && pytruth(credentials.refresh_token)
                    credentials.refresh(Request())
                else
                    credentials = auth(secretpath, scopes)
                end
            end
        else
            credentials = auth(secretpath, scopes)
        end
    else
        credentials = auth(secretpath, scopes)
    end
    open(tokenpath, "w") do io
        write(io, credentials.to_json() |> string)
    end
    build(name, version; credentials)
end