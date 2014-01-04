class Episode < ActiveRecord::Base
  # Used durring creation to verify that the episode is an audio podcast.
  attr_accessor :podcast_type

  #-- Associations
  belongs_to :podcast
  has_one :queued_episode, dependent: :destroy
  has_one :episode_data

  #-- Validations
  validates :podcast, :title, :audio_url, :publication_date, :podcast_type, presence: true, allow_blank?: false
  validates :audio_url, uniqueness: true
  validates :guid, uniqueness: true, unless: 'guid.blank?'
  validates :podcast_type, inclusion: {in: [:audio], message: "%{value} is not audio"}

  accepts_nested_attributes_for :episode_data

  #-- Scopes
  default_scope { order(publication_date: :desc) }

  def is_played
    self.episode_data.try(&:is_played)
  end

  def is_played= bool
    if self.episode_data
      self.episode_data.is_played = bool
      self.episode_data.save
    else
      self.create_episode_data(is_played: bool)
    end
  end

  def current_position
    self.episode_data.try(&:current_position)
  end

  def current_position= time
    if self.episode_data
      self.episode_data.current_position = time
      self.episode_data.save
    else
      self.create_episode_data(current_position: time)
    end
  end

  def self.parse_feed(node)
    episode = Hash.new

    episode[:title] = node.xpath('title').text
    episode[:link_url] = node.xpath('link').text
    episode[:description] = node.xpath('description').text
    episode[:guid] = node.xpath('guid').text

    episode[:publication_date] = node.xpath('pubDate').text

    enclosure = node.xpath('enclosure').first
    # This application only supports audio podcasts
    if enclosure && enclosure[:type].match(/audio/)
      episode[:podcast_type] = :audio
      episode[:audio_url] = enclosure[:url]
    else
      episode[:podcast_type] = :other
    end

    return episode
  end
end
