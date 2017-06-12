Function New-ServiceHost([ZLocation.Service]$service) {
    New-Object ServiceHost($service)
}

class ServiceHost {
    # Including a GUID to make our pipe name very unique.
    static $pipeName = '0de4669d-83cd-4a61-b112-75d5f5d40481-zlocation-pipe'

    ServiceHost([ZLocation.Service]$service) {
        $this.service = $service
        $this.pipeServer = New-Object ZLocation.IpcServer([ServiceHost]::pipeName, {
            param($message)
            # unpack the request, delegate to the service, reply with a response object
            $rpcRequest = [RpcRequest]($message | ConvertFrom-Json)
            $rpcResponse = $this.callServiceMethod($rpcRequest)
            return $rpcResponse | ConvertTo-Json -Compress
        }.GetNewClosure())

        $this.pipeServer.Start()
    }

    [ZLocation.IpcServer]$pipeServer
    [ZLocation.Service]$service

    [RpcResponse] callServiceMethod([RpcRequest] $rpcRequest) {
        $response = new-object RpcResponse
        try {
            $response.return = $this.service.$($rpcRequest.method).Invoke($rpcRequest.arguments)
        } catch {
            $response.exception = $_.Exception
        }
        return $response
    }
}

Function New-ServiceProxy {
    New-Object ServiceProxy
}

class ServiceProxy {
    ServiceProxy() {
        $this.pipeClient = New-Object ZLocation.IpcClient([ServiceHost]::pipeName)
    }

    [ZLocation.IpcClient]$pipeClient

    [object] _call($method, $args) {
        $request = @{
            method = $method;
            args = $args;
        } | ConvertTo-Json -Compress
        $response = [RpcResponse]($this.pipeClient.request($request))
        if($response.exception -ne $null) { throw $response.exception }
        return $response.return
    }

    # Implement the IService interface below

    Add([string]$path, [double]$weight) {
        $this._call('Add', @($path, $weight))
    }
    Remove([string]$path) {
        $this._call('Remove', @($path))
    }
    [object] Get() { # TODO fix the return type
        return $this._call('Get', @())
    }
    Noop() {
        $this._call('Noop', @())
    }
}

class RpcRequest {
    $method
    $arguments
}

class RpcResponse {
    $return
    $exception
}
