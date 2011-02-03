Delayed::Job.destroy_failed_jobs = 'true'
Delayed::Worker.logger = Rails.logger

silence_warnings do
  Delayed::Job.const_set("MAX_ATTEMPTS", 0)
  Delayed::Job.const_set("MAX_RUN_TIME", 5.minutes)
end

ENV["RUN_WORKER"] = 'true'
