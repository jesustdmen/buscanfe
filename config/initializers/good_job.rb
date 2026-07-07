# Fila DB-backed (sem Redis). Execução no WORKER dedicado (:external) — o web só enfileira.
# SINGLE-WORKER: concorrência 1 nas chamadas SEFAZ (serializado é requisito).
Rails.application.configure do
  config.active_job.queue_adapter = :good_job
  config.good_job.execution_mode  = :external
  config.good_job.max_threads     = 1     # concorrência 1
  config.good_job.queues          = "*"
  config.good_job.poll_interval    = 5
  config.good_job.shutdown_timeout = 25
end
