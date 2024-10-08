require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

def clean_zipcode(zipcode)
    return zipcode.to_s.rjust(5,'0')[0..4]
end

def clean_phone_numbers(phone_number)
    phone_number = phone_number.to_s
    unless phone_number.length < 10 || phone_number.length > 11
        if phone_number.length == 10
            return phone_number
        elsif phone_number == 11 && phone_number[0] == "1"
            return phone_number[0..10]
        end
    end
end

def peak_registration_hour(datetime)
    reg_datetime = DateTime.strptime(datetime,'%m/%d/%Y %H:%M')
    time_of_day = reg_datetime.hour
    day_of_week = reg_datetime.wday

    return time_of_day, day_of_week
end


def legislators_by_zipcode(zip)
    civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
    civic_info.key = File.read('secret.key').strip

    begin
        legislators = civic_info.representative_info_by_address(
            address: zip,
            levels: 'country',
            roles: ['legislatorUpperBody', 'legislatorLowerBody']
        ).officials

        # legislator_names = legislators.map(&:name)
        # legislator_names = legislators.map do |legislator|
        #     legislator.name
        # end

        # legislator_names.join(", ")

    rescue => e
        puts "#{e.message}"
        legislators = "You can find your rep by visiting some website."
    end
end

def save_thank_you_letter(id,form_letter)
    Dir.mkdir('output') unless Dir.exist?('output')

    filename = "output/thanks_#{id}.html"

    File.open(filename, 'w') do |file|
        file.puts form_letter
    end
end

puts 'Event Manager Initialized!'

contents = CSV.open('event_attendees.csv', headers: true, header_converters: :symbol)

time, day = [],[]

contents.each do |row|
    id = row[0]
    
    name = row[:first_name]
    
    zipcode = clean_zipcode(row[:zipcode])

    time_of_day, day_of_week = peak_registration_hour(row[:regdate])
    time << time_of_day
    day << day_of_week


    legislators = legislators_by_zipcode(zipcode)

    form_letter = erb_template.result(binding)

    save_thank_you_letter(id,form_letter)

    # personal_letter = template_letter.gsub('FIRST_NAME', name)
    # personal_letter.gsub!('LEGISLATORS', legislators)

end

puts "The hour with most registrations is #{time.group_by {|e| e}.values.max_by(&:size).first}."
puts "The day with the most registrations is #{day.group_by {|e| e}.values.max_by(&:size).first}."



