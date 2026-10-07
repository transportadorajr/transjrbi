# Configuração do GoodJob (backend do Active Job baseado em PostgreSQL).
# Documentação: https://github.com/bensheldon/good_job#configuration
Rails.application.configure do
  # Em desenvolvimento os jobs são executados pelo processo `worker` do Procfile.dev
  # (`bundle exec good_job start`), igual ao que será usado em produção.
  config.good_job.execution_mode = Rails.env.test? ? :inline : :external

  # Filas processadas pelo worker ("*" = todas).
  config.good_job.queues = ENV.fetch('GOOD_JOB_QUEUES', '*')
  config.good_job.max_threads = ENV.fetch('GOOD_JOB_MAX_THREADS', 5).to_i
  config.good_job.poll_interval = 5 # segundos
  config.good_job.shutdown_timeout = 25 # segundos

  # Mantém o histórico de jobs concluídos (visível no dashboard /good_job).
  config.good_job.preserve_job_records = true
  config.good_job.cleanup_preserved_jobs_before_seconds_ago = 14.days.to_i

  # Tarefas agendadas (cron). Adicione entradas em `config.good_job.cron` quando precisar.
  config.good_job.enable_cron = true
  config.good_job.cron = {
    # exemplo: {
    #   cron: "0 3 * * *", # todo dia às 03:00
    #   class: "ExemploJob",
    #   description: "Descrição da tarefa"
    # }
  }
end
