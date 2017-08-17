class Marketing::PushNotification::Service

  REGISTRATION_ACCEPTED_RESPONSE = IceNine.deep_freeze(["accepted", nil])
  REGISTRATION_INACTIVE_RESPONSE = IceNine.deep_freeze(["inactive", ["This Push Notification is not activated."]])
  REGISTRATION_CONFLICT_RESPONSE = IceNine.deep_freeze(["conflict", ["Execution with same send_at already exists."]])

  class << self
    def register(push_notification, send_at: nil, override: nil, on_edit: false)
      return if push_notification.target_is_api? && !send_at

      unless push_notification.activated
        push_notification.executions.where(sent_at: nil).
          update_all(state: Marketing::PushNotification::Execution.states[:canceled])
        return REGISTRATION_INACTIVE_RESPONSE
      end

      # start_at より以前の時間に send_at がセットされている execution をキャンセルする
      push_notification.executions.ready.where("send_at < ?", push_notification.start_at).
        update_all(state: Marketing::PushNotification::Execution.states[:canceled])

      case push_notification.kind
      when "repeatable"

        if push_notification.recurring?
          # 定期実行

          # 次の発射の時刻
          # 編集時、現在時刻より準備時間以内に定期配信の予約することができるが、実際に配信されるのはその次の配信から
          send_at ||= push_notification.next_send_at(on_edit ? Marketing::PushNotification::Execution::PREPARE_SECURED_DURATION.to_i : 0)

          # end_at より send_at が先ならば中止
          return REGISTRATION_INACTIVE_RESPONSE if push_notification.end_at && push_notification.end_at < send_at

          # 現在時刻より未来の send_at が異なるものはキャンセル
          push_notification.
            executions.
            where("send_at > ?", Time.current).where.not(send_at: send_at).
            update_all(state: Marketing::PushNotification::Execution.states[:canceled])

          # execution をダブって作成しない
          unless push_notification.executions.
              where(send_at: send_at).
              where.not(state: Marketing::PushNotification::Execution.states[:canceled]).
              count == 0
            return REGISTRATION_CONFLICT_RESPONSE
          end
        end

      when "single"
        send_at ||= push_notification.send_at
        execution = push_notification.executions.ready.first
      end

      return REGISTRATION_INACTIVE_RESPONSE unless push_notification.start_at <= send_at

      execution ||= push_notification.executions.build
      execution.send_at = send_at

      execution.override = override if override
      begin
        ActiveRecord::Base.transaction do
          execution.save!
          # 現在一度設定した push の conversion event を変更することは想定していない。
          # する場合、予約配信や定期配信が作成されてから conversion event のみが変更されたとき、
          # `create_campaign_targets` が呼ばれることを担保する必要がある。
          execution.create_campaign_targets
        end
      rescue ActiveRecord::RecordInvalid
        ["execution invalid", execution.errors.full_messages]
      else
        REGISTRATION_ACCEPTED_RESPONSE
      end
    end
  end
end
