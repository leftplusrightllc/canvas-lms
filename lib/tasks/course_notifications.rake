# This task should be executed every day at the beginnig of the day
namespace :courses do
  desc "Trigger email notifications for each course starting today."
  task :started_notification => :environment do
    Course.where(start_at: Date.today.beginning_of_day..Date.today.end_of_day).each do |course|
      course.enrollments.each do |e|
        m = Message.new({
                         :to => e.user.email,
                         :subject => "Course #{course.full_name} starting today",
                         :body => "Dear #{e.user.name}, the course \"#{course.full_name}\" is starting today at #{course.start_at}."
                     })
        Mailer.create_message_custom(m).deliver
      end
    end
  end
end