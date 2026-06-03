# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Async
	module HTTP
		module Protocol
			module HTTP3
				# Writes a readable HTTP body to an HTTP/3 stream from a separate task.
				class Output
					# Initialize the output writer.
					# @parameter stream [Protocol::HTTP3::Stream] The HTTP/3 stream.
					# @parameter body [Protocol::HTTP::Body::Readable] The body to write.
					def initialize(stream, body)
						@stream = stream
						@body = body
						@task = nil
					end
					
					# Start writing the body in a child task.
					def start(parent: Task.current)
						raise "Task already started!" if @task
						
						@task = parent.async(&self.method(:run))
					end
					
					# Wait for the output task to finish.
					def wait
						@task&.wait
					end
					
					# Stop the output task.
					def stop(error = nil)
						if task = @task
							@task = nil
							task.stop(error)
						end
					end
					
					private
					
					def run(task)
						task.annotate("Writing #{@body} to #{@stream}.")
						
						while chunk = @body&.read
							@stream.write_chunk(chunk)
						end
					rescue => error
						@stream.reset
						raise
					ensure
						if body = @body
							@body = nil
							body.close(error)
						end
						
						@stream.finish unless error
					end
				end
			end
		end
	end
end
