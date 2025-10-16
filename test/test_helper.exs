# Start ExUnit
ExUnit.start()

# Ensure erlexec is started for tests
# Run as root with root user (required in Docker)
case :exec.start_link([{:root, true}, {:user, "root"}]) do
  {:ok, _} -> :ok
  {:error, {:already_started, _}} -> :ok
  error -> IO.warn("Could not start erlexec: #{inspect(error)}")
end
