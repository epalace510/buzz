
namespace :feeds do
  desc "Updates all podcasts and creates new episodes"
  task :update => :environment do
    start_time = Time.now.to_s #strftime('%d/%m/%Y %H:%M')

    Rails.logger.tagged('feeds:update', start_time) { Rails.logger.info "Getting new episodes from podcast feeds" }
    puts "Getting new episodes from podcast feeds"
    Podcast.find_each do |podcast|

      # Get old episodes to later diff against new episodes
      old_episodes = podcast.episodes.load.to_a
      old_categories = podcast.categories.load.to_a

      invalid_episodes = []

      #-- Update the podcast, and podcasts episodes
      # Pass 0 ttl to skip cache
      begin
        podcast_data = Podcast.parse_feed podcast.feed_url, 0
      rescue OpenURI::HTTPError => ex
        puts "Could not reache feed #{ex.message}"
        Rails.logger.tagged('feeds:update', start_time, podcast.title) { "Could not reache feed #{ex.message}" }
        next
      end

      # Map string categories to Categories
      podcast_data[:categories] = podcast_data[:categories].map do |name|
        Category.find_or_initialize_by(name: name)
      end

      # Update episode data
      episode_count = podcast_data[:episodes_attributes].count
      podcast_data.delete(:episodes_attributes).each do |ea|
         episode = Episode.find_or_initialize_by(audio_url: ea[:audio_url])
         unless episode.update(ea)
           invalid_episodes << episode.errors.full_messages
         end
      end

      # Update the podcasts attributes, this also creates new episodes
      podcast.attributes = podcast_data


      # Get old title, and changed attributes.
      title = podcast.title_was
      changed_attributes = podcast.changed_attributes.dup

      podcast.save

      # Diff created/removed episodes
      episodes = podcast.episodes.load.to_a
      added_episodes = episodes - old_episodes
      removed_episodes = old_episodes - episodes

      # Diff created/removed categories
      categories = podcast.categories.load.to_a
      added_categories = categories - old_categories
      removed_categories = old_categories - categories

      #-- Print changes to podcast or episodes
      puts "-> #{title}"
      changed_attributes.each do |attr, was|
        puts "    #{attr}: #{was} -> #{podcast[attr]}"
      end


      puts "    #{invalid_episodes.count}/#{episode_count} invalid episodes #{invalid_episodes.flatten.uniq}" if invalid_episodes.count > 0
      puts "    Added #{added_episodes.count} episodes" if added_episodes.any?
      puts "    Removed #{removed_episodes.count} episodes" if removed_episodes.any?

      puts "    Added #{added_categories.count} categories" if added_categories.any?
      puts "    Removed #{removed_categories.count} categories" if removed_categories.any?

      #-- Log changes to podcast or episodes
      update_messages = Array.new
      update_messages << "+#{added_episodes.count}" if added_episodes.any?
      update_messages << "-#{removed_episodes_episodes.count}" if removed_episodes.any?
      update_messages << "#{changed_attributes.count} attributes updated" if changed_attributes.any?
      update_messages << "#{invalid_episodes.count}/#{episode_count} invalid episodes" if invalid_episodes.count > 0
      Rails.logger.tagged('feeds:update', start_time, podcast.title) { Rails.logger.info update_messages.join(", ") } if update_messages.any?
    end
  end

  desc "Dumps feeds from heroku"
  task :dump => :environment do

    output_file = Rails.configuration.feed_dump_filename
    puts "Dumping feeds from heroku to #{output_file}"

    feed_sql = "SELECT feed_url from podcasts ORDER BY podcasts.feed_url"
    output = %x{echo '#{feed_sql}' | heroku pg:psql}

    # Drip sourounding marks that are not feeds.
    trimmed_output = output.lines[2..-3]

    File.open(output_file, "w") do |f|
      trimmed_output.each do |line|
        f.write line
      end
    end

    puts "Wrote #{trimmed_output.count} feed urls to #{output_file}"
  end

  desc "Experiment with feed parse code"
  task :test => :environment do
    #-- Change pre test code below
    blank = []; one = []; many = []; all = []

    #-- Change pre test code above
    Podcast.all.each do |pod|
      parsed = Podcast.parse_feed pod.feed_url
      #-- Change test code below

      # Testing category results. Not many podcasts use media:category
      puts "#{pod.title}:	#{parsed[:categories]}"

      if parsed[:categories].blank?
        blank << parsed
      elsif parsed[:categories].length == 1
        one << parsed
      elsif parsed[:categories].length > 1
        many << parsed
      end

      all << parsed

      #-- Change test code above
    end
    #-- Change post test code below

    puts "blank: #{blank.count}. one: #{one.count}. many: #{many.count}"

    categories = all.map { |pf| pf[:categories] }.flatten

    puts categories.uniq.sort
    puts "#{categories.count} categories, #{categories.uniq.count} unique"

    #-- Change post test code above
  end
end
