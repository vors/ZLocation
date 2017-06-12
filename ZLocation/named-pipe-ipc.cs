using System;
using System.Threading;
using System.Text;
using System.IO;
using System.IO.Pipes;
using System.Threading.Tasks;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Collections.ObjectModel;
using System.Collections.Generic;

namespace ZLocation {
    // Delegate to handle messages on the server-side
    // The goal is that this delegate is provided by PowerShell (probably a ScriptBlock)
    // and we call it every time the server receives a message
    public delegate string MessageHandlerDelegate(string message);

    /**
     * Simple IPC server that uses named pipes under-the-hood to enable communication on the local machine.
     * Incoming messages are strings.  They are passed to a handler delegate which is expected to synchronously return
     * a string.  The response string is immediately sent to the client.
     * Internally, communication uses a named pipe in "message" transport mode.  Strings are encoded in UTF8.
     * Calls to the handler are not constrained to a single thread, are not ordered, and might be called in parallel.
     */
    public class IpcServer {

        public IpcServer(MessageHandlerDelegate handler) {
            init(null, handler);
        }
        public IpcServer(string pipeName, MessageHandlerDelegate handler) {
            init(pipeName, handler);
        }

        private void init(string pipeName, MessageHandlerDelegate handler) {
            if(pipeName != null) {
                this.pipeName = pipeName;
            }
            this.handler = handler;
            psInvoker = new PowerShellInvoker();
        }

        public const string defaultPipeName = "IpcPipeName";
        private string pipeName = defaultPipeName;
        private PowerShellInvoker psInvoker;
        Thread serverThread;
        private MessageHandlerDelegate handler;

        public void start() {
            serverThread = new Thread(runner);
            serverThread.SetApartmentState(ApartmentState.STA); // I have no idea if this is necessary and only a vague idea of what it does.
            serverThread.Start();
        }

        // Run synchronously in this thread
        public void run() {
            runner();
        }

        private void runner() {
#if WINDOWS
            PipeSecurity serverPipeSecurity = new PipeSecurity();
            serverPipeSecurity = null;
            // TODO setup pipe security
#endif
            while(true) {
                var namedPipeServer =
#if WINDOWS
                new NamedPipeServerStream(
                    pipeName,
                    PipeDirection.InOut,
                    NamedPipeServerStream.MaxAllowedServerInstances,
                    PipeTransmissionMode.Byte,
                    PipeOptions.Asynchronous,
                    1000,
                    1000,
                    serverPipeSecurity,
                    HandleInheritability.None
                );
#else
                new NamedPipeServerStream(
                    pipeName,
                    PipeDirection.InOut,
                    NamedPipeServerStream.MaxAllowedServerInstances,
                    PipeTransmissionMode.Byte,
                    PipeOptions.Asynchronous
                );
#endif
                // TODO somehow handle cancellations when the process needs to shut down.
                namedPipeServer.WaitForConnection();
                Task.Run(() => {
                    handleClient(namedPipeServer);
                });
            }
        }

        private async void handleClient(NamedPipeServerStream stream) {
            using(MessagePipe messagePipe = new MessagePipe(stream)) {
                try {
                    while(true) {
                        // Receive a message
                        string request = await messagePipe.readMessage();
                        if(request == null) return;
                        // dispatch to the server's message handler
                        string response = psInvoker.Invoke(() => {
                            return handler(request);
                        });
                        // write the result to the client
                        await messagePipe.writeMessage(response);
                    }
                } catch(MessagePipe.BrokenOrClosedPipeException) {
                    return;
                }
            }
        }
    }

    public class IpcClient {
        public IpcClient() {}
        public IpcClient(string pipeName) {
            if(pipeName != null) {
                this.pipeName = pipeName;
            }
        }
        private string pipeName = IpcServer.defaultPipeName;
        private NamedPipeClientStream client;
        private MessagePipe messagePipe;
        public void connect() {
            connectIfNecessary();
        }
        private void connectIfNecessary() {
            if(client == null || !client.IsConnected) {
                if(client != null) client.Dispose();
                if(messagePipe != null) messagePipe.Dispose();
                client = new NamedPipeClientStream(".", pipeName, PipeDirection.InOut, PipeOptions.Asynchronous);
                client.Connect(1000);
                if(!client.IsConnected) {
                    throw new ClientCannotConnectException("Unable to connect to named pipe server.");
                }
                messagePipe = new MessagePipe(client);
            }
        }
        // Send a request to the server, wait for and return the response.
        public string request(string message) {
            connectIfNecessary();
            var t = requestAsync(message);
            t.Wait();
            if(t.IsFaulted) {
                throw t.Exception;
            } else {
                return t.Result;
            }
        }
        public async Task<string> requestAsync(string message) {
            await messagePipe.writeMessage(message);
            string response = await messagePipe.readMessage();
            return response;
        }

        public class ClientCannotConnectException : Exception {
            public ClientCannotConnectException(string message) : base(message) {}
        }
    }

    // Wrapper around named pipe server or client that exposes a common API for sending and receiving messages.
    internal class MessagePipe : IDisposable {
        public MessagePipe(NamedPipeServerStream server) {this.server = server; init();}
        public MessagePipe(NamedPipeClientStream client) {this.client = client; init();}
        private void init() {
            reader = client != null ? new StreamReader(client, Encoding.UTF8) : new StreamReader(server, Encoding.UTF8);
            writer = client != null ? new StreamWriter(client, Encoding.UTF8) : new StreamWriter(server, Encoding.UTF8);
        }
        private NamedPipeClientStream client = null;
        private NamedPipeServerStream server = null;
        private StreamReader reader;
        private StreamWriter writer;
        private bool broken = false;
        private void ensureNotBroken() {
            if(broken) throw new BrokenOrClosedPipeException("Pipe is already broken or closed; refusing to attempt operation.");
        }
        private bool IsMessageComplete {
            get {
                return (client != null ? client.IsMessageComplete : server.IsMessageComplete);
            }
        }
        private bool IsConnected {
            get {
                return (client != null ? client.IsConnected : server.IsConnected);
            }
        }
        public async Task<string> readMessage() {
            ensureNotBroken();
            // async wait for and read a message from the client
            string message = null;
            try {
                message = await reader.ReadLineAsync();
            } catch(Exception ex) {
                handleBrokenOrClosedPipeException(ex);
                throw ex;
            }
            return message;
        }
        public async Task writeMessage(string message) {
            ensureNotBroken();
            try {
                await writer.WriteLineAsync(message);
                await writer.FlushAsync();
            } catch(Exception ex) {
                handleBrokenOrClosedPipeException(ex);
                throw ex;
            }
        }
        private void handleBrokenOrClosedPipeException(Exception ex) {
            if(ex is IOException || ex is ObjectDisposedException) {
                broken = true;
                throw new BrokenOrClosedPipeException("Pipe is presumed closed or broken.", ex);
            }
        }
        public void Dispose() {
            if(client != null) client.Dispose();
            if(server != null) server.Dispose();
            if(reader != null) reader.Dispose();
            if(writer != null) writer.Dispose();
        }

        public class BrokenOrClosedPipeException : Exception {
            public BrokenOrClosedPipeException(string message) : base(message) {}
            public BrokenOrClosedPipeException(string message, Exception ex) : base(message, ex) {}
        }
    }

    public delegate T Callback<T>();

    /**
     * The simplest way to invoke PowerShell callbacks from multi-threaded C#.
     * Creates a runspace on its own thread. Any invocation requests are run
     * on that thread.
     */
    public class PowerShellInvoker {
        public PowerShellInvoker() {
            pool = RunspaceFactory.CreateRunspacePool(1, 1);
#if WINDOWS
            pool.ApartmentState = ApartmentState.STA;
#endif
            pool.Open();
        }

        private RunspacePool pool;

        /**
         * Powershell can't do automatic conversion of a ScriptBlock to a generic delegate
         * because it can't figure out the generic parameters.
         * To avoid forcing PowerShell scripters to explicitly perform type conversion,
         * we expose this method that doesn't care about type information; it assumes your
         * delegate returns an object
         */
        public object InvokeDynamic(Callback<object> cb) {
            return Invoke(cb);
        }

        public T Invoke<T>(Callback<T> cb) {
            PowerShell ps = PowerShell.Create();
            ps.RunspacePool = pool;
            ps.AddScript(@"
                return $args[0].Invoke()
            ");
            ps.AddArgument(cb);
            Collection<PSObject> results = ps.Invoke();
            if(ps.InvocationStateInfo.State == PSInvocationState.Failed) {
                throw ps.InvocationStateInfo.Reason;
            }
            if(results.Count != 1) {
                throw new WrongNumberOfReturnValuesException("Expected exactly 1 return value; got " + results.Count, ps.Streams.Error.GetEnumerator());
            }
            object result = results[0].ImmediateBaseObject;
            if(result is T) {
                return (T)result;
            } else {
                return default(T); // TODO THROW AN ERROR(?)
            }
        }

        public class WrongNumberOfReturnValuesException : Exception {
            public WrongNumberOfReturnValuesException(string message, IEnumerator<ErrorRecord> errors) : base(message) {
                this.ErrorStreamRecords = errors;
            }
            public IEnumerator<ErrorRecord> ErrorStreamRecords;
        }
    }
}
