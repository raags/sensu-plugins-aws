#! /usr/bin/env ruby
#
# check-datapipeline
#
# DESCRIPTION:
#   Check and alert for AWS datapipeline
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: aws-sdk
#   gem: sensu-plugin
#
# USAGE:
#   ./check-datapipeline.rb --pipeline-name mypipeline --status 'SCHEDULED|RUNNING' --health 'HEALTHY'
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2016, Raghu Udiyar<raghusiddarth@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'aws-sdk'

class CheckDatapipeline < Sensu::Plugin::Check::CLI
  option :aws_access_key,
         short: '-a AWS_ACCESS_KEY',
         long: '--aws-access-key AWS_ACCESS_KEY',
         description: "AWS Access Key. Either set ENV['AWS_ACCESS_KEY'] or provide it as an option",
         default: ENV['AWS_ACCESS_KEY']

  option :aws_secret_access_key,
         short: '-k AWS_SECRET_KEY',
         long: '--aws-secret-access-key AWS_SECRET_KEY',
         description: "AWS Secret Access Key. Either set ENV['AWS_SECRET_KEY'] or provide it as an option",
         default: ENV['AWS_SECRET_KEY']

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1).',
         default: 'us-east-1'

  option :pipeline_name,
         short: '-p PIPELINE_NAME',
         long: '--pipeline-name',
         description: 'The name of the data pipeline',
         required: true

  option :status,
         short: '-s STATUS_REGEX',
         long: '--status',
         description: 'Pipeline status regex',
         required: true

  option :health,
         short: '-h HEALTH_REGEX',
         long: '--health',
         description: 'Pipeline health regex',
         required: true

  def aws_config
    { access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region]
    }
  end

  def datapipeline
    @datapipeline = Aws::DataPipeline::Client.new aws_config
  end

  def get_pipeline_id(pipeline_name)
    pipelines = datapipeline.list_pipelines
    pipelines['pipeline_id_list'].each do |pipeline|
      if pipeline.name == pipeline_name
        return pipeline.id
      end
    end
    return nil
  end

  def pipeline_field(key, fields)
   fields.each do |field|
      return field.string_value if field.key == key
    end
  end

  def get_pipeline_state(pipeline_id)
    params = { :pipeline_ids => [pipeline_id] }
    pipeline_desc = datapipeline.describe_pipelines params
    fields = pipeline_desc.pipeline_description_list[0].fields
    status = pipeline_field('@pipelineState', fields)
    health = pipeline_field('@healthStatus', fields)
    return [status, health]
  end

  def run
    begin
      pipeline_id = get_pipeline_id(config[:pipeline_name])
      if pipeline_id.nil?
        critical "Pipeline #{config[:pipeline_name]} not found!"
      end
      status, health = get_pipeline_state(pipeline_id)
      if status =~ /#{config[:status]}/ and health =~ /#{config[:health]}/
        ok "Pipeline '#{config[:pipeline_name]}' status is '#{status}' and health is '#{health}'"
      else
        critical "Unmatched state - pipeline '#{config[:pipeline_name]}' status is '#{status}' and health is '#{health}'"
      end
    rescue => e
      unknown "Pipeline '#{config[:pipeline_name]}' - #{e.message}"
    end
  end
end
