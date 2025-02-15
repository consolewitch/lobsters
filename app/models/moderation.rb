class Moderation < ApplicationRecord
  belongs_to :moderator,
             :class_name => "User",
             :foreign_key => "moderator_user_id",
             :inverse_of => :moderations,
             :optional => true
  belongs_to :comment,
             :optional => true
  belongs_to :domain,
             :optional => true
  belongs_to :story,
             :optional => true
  belongs_to :tag,
             :optional => true
  belongs_to :user,
             :optional => true
  belongs_to :category,
             :optional => true

  scope :for, ->(user) {
    left_outer_joins(:story, :comment) .where("
      moderations.user_id = ? OR
      stories.user_id = ? OR
      comments.user_id = ?", user, user, user)
  }

  validates :action, :reason, length: { maximum: 16_777_215 }
  validate :one_foreign_key_present

  after_create :send_message_to_moderated

  def send_message_to_moderated
    m = Message.new
    m.author_user_id = self.moderator_user_id

    # mark as deleted by author so they don't fill up moderator message boxes
    m.deleted_by_author = true

    if self.story
      m.recipient_user_id = self.story.user_id
      m.subject = "Your story has been edited by " <<
                  (self.is_from_suggestions? ? "user suggestions" : "a moderator")
      m.body = "Your story [#{self.story.title}](" <<
               "#{self.story.comments_url}) has been edited with the following " <<
               "changes:\n" <<
               "\n" <<
               "> *#{self.action}*\n"

      if self.reason.present?
        m.body << "\n" <<
          "The reason given:\n" <<
          "\n" <<
          "> *#{self.reason}*\n" <<
          "\n" <<
          "Maybe the guidelines on topicality are useful: https://lobste.rs/about#topicality"
      end

    elsif self.comment
      m.recipient_user_id = self.comment.user_id
      m.subject = "Your comment has been moderated"
      m.body = "Your comment on [#{self.comment.story.title}](" <<
               "#{self.comment.story.comments_url}) has been moderated:\n" <<
               "\n" <<
               "> *#{self.comment.comment}*\n"

      if self.reason.present?
        m.body << "\n" <<
          "The reason given:\n" <<
          "\n" <<
          "> *#{self.reason}*\n"
      end

    else
      # no point in alerting deleted users, they can't login to read it
      return
    end

    return if m.recipient_user_id == m.author_user_id

    m.body << "\n" <<
      "*This is an automated message.*"

    m.save
  end

protected

  def one_foreign_key_present
    fks = [comment_id, domain_id, story_id, category_id, tag_id, user_id].compact.length
    errors.add(:base, "moderation should be linked to only one object") if fks != 1
  end
end
