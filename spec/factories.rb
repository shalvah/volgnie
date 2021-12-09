FactoryBot.define do
  factory :user, class: "Hash" do
    id { Faker::Number.number(digits: 18).to_s }
    username { Faker::Internet.username }

    initialize_with { attributes }

    trait :with_ff do
      transient do
        followers_count { 37 }
        following_count { 5 }
      end

      followers { Array.new(followers_count) { association(:user) } }
      following { Array.new(following_count) { association(:user) } }
    end
  end
end