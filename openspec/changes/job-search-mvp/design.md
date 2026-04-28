# Design: Job Search MVP

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Rails 8 Application                         │
│        Hotwire/Turbo + Stimulus · Solid Queue · PostgreSQL      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────────┐    │
│  │  Discovery    │   │  Matching     │   │  Assisted Apply  │    │
│  │  Engine       │   │  Engine       │   │  System          │    │
│  │              │   │              │   │                  │    │
│  │ SerpApi ──────┤→ │ Stage 1 ──────┤→ │ ATS Adapters     │    │
│  │ ATS Fetcher   │   │ Stage 2 (LLM)│   │ (GH/Lever/Ashby)│    │
│  └──────┬───────┘   └──────┬───────┘   └────────┬─────────┘    │
│         │                  │                     │              │
│         ▼                  ▼                     ▼              │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Lead Pipeline (Kanban Board)                 │   │
│  │  Discovered → New → Reviewed → Applied → Interview → Offer│   │
│  │                                              ↘ Rejected   │   │
│  └──────────────────────────────────────────────────────────┘   │
│         │                  │                     │              │
│         ▼                  ▼                     ▼              │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │           Solid Queue (Background Processing)             │   │
│  │  :discovery · :matching · :apply · :default · :low        │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

External Dependencies:
  ├── SerpApi (Google SERP queries)
  ├── Anthropic API via ruby_llm (Claude Haiku for Stage 2)
  ├── Greenhouse Public API (boards-api.greenhouse.io)
  ├── Lever Public API (api.lever.co)
  └── Ashby Public API (api.ashbyhq.com)
```

### Data Flow

```
User configures Search Profile
         │
         ▼
  ┌─────────────────────┐
  │  DiscoveryJob (cron) │  ← Solid Queue recurring, 1x/24h
  │  "site:lever.co      │
  │   'Senior Rails'"    │
  └──────────┬──────────┘
             │ SerpApi JSON
             ▼
  ┌─────────────────────┐
  │  Discovery::         │  Parse SERP results,
  │  ResultParser        │  detect ATS type from URL,
  │                      │  dedup via fingerprint
  └──────────┬──────────┘
             │ New Lead records (stage: :discovered)
             ▼
  ┌─────────────────────┐
  │  Stage1MatchingJob   │  ← Enqueued per lead
  │  Keyword filter      │  required_keywords ∩ description
  │  (free, <1ms)        │
  └──────────┬──────────┘
             │ pass → enqueue Stage 2
             │ fail → stage: :rejected
             ▼
  ┌─────────────────────┐
  │  Stage2MatchingJob   │  ← Enqueued per lead
  │  LLM evaluation      │  ruby_llm → Claude Haiku
  │  (~$0.002/eval)      │  Structured JSON output
  └──────────┬──────────┘
             │ score >= threshold → stage: :new (appears on board)
             │ score <  threshold → stage: :rejected
             ▼
  ┌─────────────────────┐
  │  Kanban Board (UI)   │  Hotwire + SortableJS
  │  User reviews,       │  Drag-and-drop state changes
  │  drags, applies      │  Turbo Stream broadcasts
  └──────────┬──────────┘
             │ User clicks "Apply with Assistant"
             ▼
  ┌─────────────────────┐
  │  Apply::Orchestrator │  Detects ATS type,
  │  → ATS Adapter       │  fetches form fields,
  │  → Form pre-fill     │  returns pre-fill payload
  └─────────────────────┘
```

### Key Design Decisions

| Decision | Choice | Alternatives Rejected | Rationale |
|----------|--------|----------------------|-----------|
| Lead stage model | Integer enum on `leads.stage` column | Separate `stages` table; AASM gem | Single-tenant MVP — no custom stages needed. Enum is simpler, faster, no joins. AASM adds unnecessary complexity for 6 fixed states. |
| Deduplication | SHA256 fingerprint (`url`) with unique index | Fuzzy matching on title+company | URL is the canonical identifier for a job posting. Same job on different URLs IS a different lead entry (different apply flow). Fuzzy matching is Phase 2 enhancement. |
| ATS detection | URL pattern matching in `Lead` model | Separate ATS registry table | Only 3 ATS platforms in MVP. Simple regex on domain. Table-based registry is overengineering for 3 patterns. |
| LLM integration | ruby_llm gem (Claude Haiku) | Direct Anthropic SDK; LangChain.rb | ruby_llm has Rails integration (`acts_as_chat`), structured output, multi-provider fallback. By thoughtbot. Single gem covers all LLM needs. |
| Frontend | Hotwire + SortableJS via importmap | React; ViewComponent | Spec mandates Hotwire-native. SortableJS is the proven lib for drag-and-drop with Turbo. Importmap = no Node.js build step. |
| Background processing | Solid Queue | Sidekiq | Spec mandates Solid Queue. No Redis. Built-in `limits_concurrency` for rate limiting. `config/recurring.yml` for cron. Perfect for single-user. |
| Assisted apply strategy | Server-side payload generation + client review | Full auto-submit; Browser extension | MVP safety: generate pre-fill data server-side, user reviews and submits manually. No ToS risk. Extension is Phase 2. |
| No multi-user auth | Single-user, no Devise | Devise authentication | Spec says single-tenant MVP. No auth overhead. Add Devise when multi-user needed. |

---

## 2. Database Schema

### ERD (Text-Based)

```
┌──────────────────────────┐       ┌──────────────────────────────┐
│        profiles           │       │      search_queries          │
├──────────────────────────┤       ├──────────────────────────────┤
│ id              :bigint  │       │ id                :bigint    │
│ full_name       :string  │       │ profile_id        :bigint FK │
│ email           :string  │       │ query_template    :string    │
│ phone           :string  │──┐    │ ats_portal        :string    │
│ linkedin_url    :string  │  │    │ role_keyword      :string    │
│ github_url      :string  │  │    │ location_keyword  :string    │
│ website_url     :string  │  │    │ extra_terms       :string    │
│ location        :string  │  │    │ enabled           :boolean   │
│ resume_text     :text    │  │    │ last_run_at       :datetime  │
│ cover_letter    :text    │  │    │ created_at        :datetime  │
│ common_answers  :jsonb   │  │    │ updated_at        :datetime  │
│ created_at      :datetime│  │    └──────────────────────────────┘
│ updated_at      :datetime│  │
└──────────────────────────┘  │    ┌──────────────────────────────┐
                               │    │   matching_criteria          │
                               │    ├──────────────────────────────┤
                               ├───▶│ id                :bigint    │
                               │    │ profile_id        :bigint FK │
                               │    │ required_keywords :jsonb     │
                               │    │ negative_keywords :jsonb     │
                               │    │ preferred_keywords:jsonb     │
                               │    │ min_salary        :integer   │
                               │    │ max_salary        :integer   │
                               │    │ locations         :jsonb     │
                               │    │ employment_types  :jsonb     │
                               │    │ remote_preference :string    │
                               │    │ min_match_score   :integer   │
                               │    │ created_at        :datetime  │
                               │    │ updated_at        :datetime  │
                               │    └──────────────────────────────┘
                               │
                               │    ┌──────────────────────────────────┐
                               │    │            leads                  │
                               │    ├──────────────────────────────────┤
                               ├───▶│ id                  :bigint      │
                                    │ profile_id          :bigint FK   │
                                    │ search_query_id     :bigint FK   │
                                    │ company_name        :string      │
                                    │ title               :string      │
                                    │ url                 :string      │
                                    │ ats_type            :string      │
                                    │ ats_company_slug    :string      │
                                    │ ats_job_id          :string      │
                                    │ location            :string      │
                                    │ salary_min          :integer     │
                                    │ salary_max          :integer     │
                                    │ employment_type     :string      │
                                    │ description         :text        │
                                    │ parsed_data         :jsonb       │
                                    │ date_posted         :date        │
                                    │ stage               :integer     │
                                    │ stage_position      :integer     │
                                    │ keyword_match       :boolean     │
                                    │ match_score         :integer     │
                                    │ match_recommendation:string      │
                                    │ match_reasoning     :text        │
                                    │ match_strengths     :jsonb       │
                                    │ match_concerns      :jsonb       │
                                    │ fingerprint         :string      │
                                    │ discovered_at       :datetime    │
                                    │ created_at          :datetime    │
                                    │ updated_at          :datetime    │
                                    └──────────┬───────────────────────┘
                                               │
                               ┌───────────────┼──────────────────┐
                               │               │                  │
                               ▼               ▼                  ▼
┌──────────────────────────┐  ┌──────────────────────┐  ┌─────────────────────┐
│       applications       │  │       notes           │  │  lead_events        │
├──────────────────────────┤  ├──────────────────────┤  ├─────────────────────┤
│ id           :bigint     │  │ id         :bigint   │  │ id          :bigint │
│ lead_id      :bigint FK  │  │ lead_id    :bigint FK│  │ lead_id     :bigint │
│ status       :integer    │  │ content    :text     │  │ from_stage  :string │
│ ats_type     :string     │  │ created_at :datetime │  │ to_stage    :string │
│ form_payload :jsonb      │  │ updated_at :datetime │  │ trigger     :string │
│ form_responses :jsonb    │  └──────────────────────┘  │ metadata    :jsonb  │
│ ats_response :jsonb      │                            │ created_at  :datetime│
│ error_message :text      │                            └─────────────────────┘
│ submitted_at :datetime   │
│ created_at   :datetime   │
│ updated_at   :datetime   │
└──────────────────────────┘
```

### Enum Definitions

```ruby
# Lead stages (integer enum)
enum :stage, {
  discovered:       0,  # Just found by SerpApi, not yet evaluated
  pending_matching: 1,  # Passed Stage 1, waiting for Stage 2
  new:              2,  # Passed matching, visible on Kanban
  reviewed:         3,  # User has reviewed the lead
  applied:          4,  # Application submitted
  interview:        5,  # Interview stage
  offer:            6,  # Offer received
  rejected:         7   # Rejected at any point
}, default: :discovered, validate: true

# Application statuses (integer enum)
enum :status, {
  draft:     0,  # Pre-fill generated, not yet submitted
  submitted: 1,  # Successfully submitted to ATS
  failed:    2,  # Submission failed
  manual:    3   # User applied manually, tracking only
}, default: :draft, validate: true

# Match recommendations (string — from LLM output)
# "APPLY" | "MAYBE" | "SKIP"

# ATS types (string — from URL pattern detection)
# "greenhouse" | "lever" | "ashby" | nil

# Remote preference (string)
# "remote" | "hybrid" | "onsite" | "any"

# Lead event triggers (string)
# "discovery" | "stage1_match" | "stage2_match" | "user_drag" | "auto_apply" | "manual"
```

### Index Strategy

```ruby
# leads table — critical for performance
add_index :leads, :fingerprint, unique: true                           # Dedup
add_index :leads, [:profile_id, :stage, :stage_position]               # Kanban board query
add_index :leads, [:profile_id, :stage, :match_score],
          name: "idx_leads_for_board_sort"                             # Sort by score within stage
add_index :leads, [:profile_id, :created_at],
          name: "idx_leads_for_recent"                                 # Recent discoveries

# search_queries table
add_index :search_queries, [:profile_id, :enabled]
add_index :search_queries, [:profile_id, :last_run_at]

# applications table
add_index :applications, :lead_id, unique: true                        # One application per lead

# lead_events table
add_index :lead_events, [:lead_id, :created_at]                        # Timeline per lead

# notes table
add_index :notes, [:lead_id, :created_at]
```

### Design Rationale: No STI, No Polymorphic

- **No STI for leads**: All leads have the same fields regardless of ATS source. `ats_type` string differentiates behavior at the service layer, not the model layer.
- **No STI for search_queries**: All queries follow the same SerpApi pattern (`site:<portal> "<keyword>"`). The `ats_portal` column differentiates.
- **No polymorphic for notes**: Notes only belong to leads. If we later add notes to other models, we can add polymorphic then. YAGNI.
- **`profiles` not `users`**: Single-tenant MVP has no authentication. `Profile` represents the job seeker's data. When we add Devise later, `Profile` becomes `belongs_to :user`.

---

## 3. Service Layer Design

### `app/services/discovery/`

```ruby
# app/services/discovery/orchestrator.rb
# Runs the full discovery pipeline for a profile
module Discovery
  class Orchestrator
    # @param profile_id [Integer]
    # @return [Hash] { success: Boolean, response: { new_leads: Integer, duplicates: Integer } }
    def self.call(profile_id:)
      new(profile_id:).call
    end

    def call
      profile = Profile.find(profile_id)
      queries = profile.search_queries.enabled

      total_new = 0
      total_dupes = 0

      queries.each do |query|
        next if query.recently_run? # 24h cooldown

        result = QueryExecutor.call(query:)
        next unless result[:success]

        parsed = ResultParser.call(
          serp_results: result[:response][:results],
          profile:,
          search_query: query
        )

        total_new += parsed[:response][:new_count]
        total_dupes += parsed[:response][:duplicate_count]

        query.update!(last_run_at: Time.current)
      end

      { success: true, response: { new_leads: total_new, duplicates: total_dupes } }
    end
  end
end

# app/services/discovery/query_executor.rb
# Calls SerpApi with a constructed Google dork query
module Discovery
  class QueryExecutor
    # @param query [SearchQuery] the query record with portal, keywords, etc.
    # @return [Hash] { success: Boolean, response: { results: Array<Hash>, total: Integer } }
    def self.call(query:)
      new(query:).call
    end

    def call
      search_string = build_query_string(query)
      response = serp_client.search(q: search_string, engine: "google", num: 100)
      results = response.dig("organic_results") || []

      { success: true, response: { results:, total: results.size } }
    rescue SerpApi::Error => e
      Rails.logger.error("SerpApi error", { event: "discovery.serp_error", error: e.message })
      { success: false, response: { error: e.message } }
    end

    private

    # Builds: site:jobs.lever.co "Senior Rails Engineer" "remote"
    def build_query_string(query)
      parts = ["site:#{query.ats_portal}"]
      parts << "\"#{query.role_keyword}\"" if query.role_keyword.present?
      parts << "\"#{query.location_keyword}\"" if query.location_keyword.present?
      parts << query.extra_terms if query.extra_terms.present?
      parts.join(" ")
    end

    def serp_client
      @serp_client ||= SerpApi::Client.new(api_key: Rails.application.credentials.serp_api_key)
    end
  end
end

# app/services/discovery/result_parser.rb
# Parses SerpApi results, detects ATS type, creates Lead records
module Discovery
  class ResultParser
    # @param serp_results [Array<Hash>] raw SERP organic results
    # @param profile [Profile]
    # @param search_query [SearchQuery]
    # @return [Hash] { success: Boolean, response: { new_count: Integer, duplicate_count: Integer } }
    def self.call(serp_results:, profile:, search_query:)
      new(serp_results:, profile:, search_query:).call
    end

    def call
      new_count = 0
      duplicate_count = 0

      serp_results.each do |result|
        url = result["link"]
        fingerprint = Digest::SHA256.hexdigest(url)

        if Lead.exists?(fingerprint:)
          duplicate_count += 1
          next
        end

        ats_info = AtsDetector.call(url:)

        Lead.create!(
          profile:,
          search_query:,
          title: result["title"],
          url:,
          fingerprint:,
          ats_type: ats_info[:type],
          ats_company_slug: ats_info[:slug],
          ats_job_id: ats_info[:job_id],
          parsed_data: result,
          stage: :discovered,
          discovered_at: Time.current
        )

        new_count += 1
      end

      { success: true, response: { new_count:, duplicate_count: } }
    end
  end
end

# app/services/discovery/ats_detector.rb
# Detects ATS type and extracts slug/job_id from URL
module Discovery
  class AtsDetector
    ATS_PATTERNS = {
      "greenhouse" => %r{boards\.greenhouse\.io/(?<slug>[^/]+)/jobs/(?<job_id>\d+)}i,
      "lever"      => %r{jobs\.lever\.co/(?<slug>[^/]+)/(?<job_id>[a-f0-9-]+)}i,
      "ashby"      => %r{jobs\.ashbyhq\.com/(?<slug>[^/]+)/(?<job_id>[a-f0-9-]+)}i
    }.freeze

    # @param url [String]
    # @return [Hash] { type: String|nil, slug: String|nil, job_id: String|nil }
    def self.call(url:)
      ATS_PATTERNS.each do |type, pattern|
        match = url.match(pattern)
        next unless match

        return { type:, slug: match[:slug], job_id: match[:job_id] }
      end

      { type: nil, slug: nil, job_id: nil }
    end
  end
end

# app/services/discovery/ats_fetcher.rb
# Fetches full job details from ATS public APIs
module Discovery
  class AtsFetcher
    # @param lead [Lead] a lead with ats_type, ats_company_slug, ats_job_id
    # @return [Hash] { success: Boolean, response: { description: String, ... } }
    def self.call(lead:)
      new(lead:).call
    end

    def call
      case lead.ats_type
      when "greenhouse"
        fetch_greenhouse
      when "lever"
        fetch_lever
      when "ashby"
        fetch_ashby
      else
        { success: false, response: { error: "UNKNOWN_ATS_TYPE" } }
      end
    end

    private

    def fetch_greenhouse
      url = "https://boards-api.greenhouse.io/v1/boards/#{lead.ats_company_slug}/jobs/#{lead.ats_job_id}"
      response = HTTParty.get(url, headers: { "Accept" => "application/json" })
      return api_error(response) unless response.success?

      data = response.parsed_response
      {
        success: true,
        response: {
          title: data["title"],
          description: ActionController::Base.helpers.strip_tags(data.dig("content")),
          location: data.dig("location", "name"),
          company_name: data.dig("company", "name") || lead.ats_company_slug,
          raw: data
        }
      }
    end

    def fetch_lever
      url = "https://api.lever.co/v0/postings/#{lead.ats_company_slug}/#{lead.ats_job_id}"
      response = HTTParty.get(url, headers: { "Accept" => "application/json" })
      return api_error(response) unless response.success?

      data = response.parsed_response
      {
        success: true,
        response: {
          title: data["text"],
          description: data.dig("descriptionPlain") || ActionController::Base.helpers.strip_tags(data["description"]),
          location: data.dig("categories", "location"),
          company_name: data.dig("categories", "team") || lead.ats_company_slug,
          raw: data
        }
      }
    end

    def fetch_ashby
      url = "https://api.ashbyhq.com/posting-api/job-board/#{lead.ats_company_slug}"
      response = HTTParty.get(url, headers: { "Accept" => "application/json" })
      return api_error(response) unless response.success?

      jobs = response.parsed_response["jobs"] || []
      job = jobs.find { |j| j["id"] == lead.ats_job_id }
      return { success: false, response: { error: "JOB_NOT_FOUND_IN_BOARD" } } unless job

      {
        success: true,
        response: {
          title: job["title"],
          description: ActionController::Base.helpers.strip_tags(job.dig("descriptionHtml") || ""),
          location: job.dig("location"),
          company_name: job.dig("organizationName") || lead.ats_company_slug,
          raw: job
        }
      }
    end

    def api_error(response)
      { success: false, response: { error: "ATS_API_ERROR", status: response.code } }
    end
  end
end
```

### `app/services/matching/`

```ruby
# app/services/matching/orchestrator.rb
# Runs Stage 1 + Stage 2 for a single lead
module Matching
  class Orchestrator
    # @param lead [Lead]
    # @return [Hash] { success: Boolean, response: { stage: String, score: Integer|nil } }
    def self.call(lead:)
      new(lead:).call
    end

    def call
      # Fetch full description if not yet available
      if lead.description.blank? && lead.ats_type.present?
        fetch_result = Discovery::AtsFetcher.call(lead:)
        if fetch_result[:success]
          lead.update!(
            description: fetch_result[:response][:description],
            company_name: fetch_result[:response][:company_name] || lead.company_name,
            location: fetch_result[:response][:location] || lead.location
          )
        end
      end

      # Stage 1: Keyword filter
      stage1 = KeywordEvaluator.call(lead:, criteria: lead.profile.matching_criterion)
      unless stage1[:response][:pass]
        lead.update!(keyword_match: false, stage: :rejected)
        log_event(lead, :discovered, :rejected, "stage1_reject")
        return { success: true, response: { stage: "rejected", score: nil } }
      end

      lead.update!(keyword_match: true, stage: :pending_matching)
      log_event(lead, :discovered, :pending_matching, "stage1_pass")

      # Stage 2: LLM evaluation (enqueue async)
      Stage2MatchingJob.perform_later(lead.id)

      { success: true, response: { stage: "pending_matching", score: nil } }
    end

    private

    def log_event(lead, from, to, trigger)
      lead.lead_events.create!(from_stage: from, to_stage: to, trigger:)
    end
  end
end

# app/services/matching/keyword_evaluator.rb
# Stage 1: Fast deterministic keyword check ($0, <1ms)
module Matching
  class KeywordEvaluator
    # @param lead [Lead]
    # @param criteria [MatchingCriterion]
    # @return [Hash] { success: Boolean, response: { pass: Boolean, matched_keywords: Array, reason: String } }
    def self.call(lead:, criteria:)
      new(lead:, criteria:).call
    end

    def call
      text = "#{lead.title} #{lead.description} #{lead.url}".downcase

      # Check negative keywords first — instant reject
      negatives_found = (criteria.negative_keywords || []).select { |kw| text.include?(kw.downcase) }
      if negatives_found.any?
        return {
          success: true,
          response: { pass: false, matched_keywords: [], reason: "NEGATIVE_KEYWORD: #{negatives_found.join(', ')}" }
        }
      end

      # Check required keywords — at least one must match
      required = criteria.required_keywords || []
      matched = required.select { |kw| text.include?(kw.downcase) }

      if required.any? && matched.empty?
        return {
          success: true,
          response: { pass: false, matched_keywords: [], reason: "NO_REQUIRED_KEYWORD_MATCH" }
        }
      end

      { success: true, response: { pass: true, matched_keywords: matched, reason: "KEYWORDS_MATCHED" } }
    end
  end
end

# app/services/matching/llm_evaluator.rb
# Stage 2: LLM semantic scoring (~$0.002/eval)
module Matching
  class LlmEvaluator
    PROMPT_TEMPLATE = <<~PROMPT
      You are a job matching evaluator. Given a job posting and a candidate's profile,
      evaluate the fit on a 0-100 scale.

      ## Candidate Profile
      Required skills: %{required_keywords}
      Preferred skills: %{preferred_keywords}
      Negative keywords (dealbreakers): %{negative_keywords}
      Salary range: %{salary_range}
      Location preferences: %{locations}
      Remote preference: %{remote_preference}

      ## Job Posting
      Title: %{job_title}
      Company: %{company_name}
      Location: %{location}
      Employment type: %{employment_type}
      Description:
      %{description}

      ## Instructions
      Score from 0-100 where:
      - 80-100: Strong match, should apply
      - 60-79: Decent match, worth reviewing
      - 40-59: Weak match, has concerns
      - 0-39: Poor match, skip

      Return ONLY valid JSON matching this exact schema.
    PROMPT

    OUTPUT_SCHEMA = {
      type: "object",
      properties: {
        score:          { type: "integer", minimum: 0, maximum: 100 },
        recommendation: { type: "string", enum: %w[APPLY MAYBE SKIP] },
        reasoning:      { type: "string", maxLength: 500 },
        strengths:      { type: "array", items: { type: "string" }, maxItems: 5 },
        concerns:       { type: "array", items: { type: "string" }, maxItems: 5 }
      },
      required: %w[score recommendation reasoning strengths concerns]
    }.freeze

    # @param lead [Lead]
    # @return [Hash] { success: Boolean, response: { score: Integer, recommendation: String, ... } }
    def self.call(lead:)
      new(lead:).call
    end

    def call
      criteria = lead.profile.matching_criterion
      prompt = format(PROMPT_TEMPLATE, prompt_vars(lead, criteria))

      chat = RubyLLM.chat(model: "claude-haiku")
      response = chat.ask(prompt, schema: OUTPUT_SCHEMA)

      parsed = response.parsed

      {
        success: true,
        response: {
          score:          parsed["score"],
          recommendation: parsed["recommendation"],
          reasoning:      parsed["reasoning"],
          strengths:      parsed["strengths"],
          concerns:       parsed["concerns"]
        }
      }
    rescue RubyLLM::Error => e
      Rails.logger.error("LLM evaluation failed", {
        event: "matching.llm_error",
        lead_id: lead.id,
        error: e.message,
        backtrace: e.backtrace&.first(5)&.join("\n")
      })
      { success: false, response: { error: e.message } }
    end

    private

    def prompt_vars(lead, criteria)
      {
        required_keywords:  (criteria.required_keywords || []).join(", "),
        preferred_keywords: (criteria.preferred_keywords || []).join(", "),
        negative_keywords:  (criteria.negative_keywords || []).join(", "),
        salary_range:       salary_range_text(criteria),
        locations:          (criteria.locations || []).join(", "),
        remote_preference:  criteria.remote_preference || "any",
        job_title:          lead.title,
        company_name:       lead.company_name || "Unknown",
        location:           lead.location || "Not specified",
        employment_type:    lead.employment_type || "Not specified",
        description:        truncate_description(lead.description)
      }
    end

    def salary_range_text(criteria)
      return "Not specified" unless criteria.min_salary || criteria.max_salary
      "$#{criteria.min_salary || '?'} - $#{criteria.max_salary || '?'}"
    end

    def truncate_description(text)
      return "No description available" if text.blank?
      text.truncate(3000) # Keep under token budget
    end
  end
end
```

### `app/services/apply/`

```ruby
# app/services/apply/orchestrator.rb
# Detects ATS type and dispatches to correct adapter
module Apply
  class Orchestrator
    ADAPTERS = {
      "greenhouse" => Apply::GreenhouseAdapter,
      "lever"      => Apply::LeverAdapter,
      "ashby"      => Apply::AshbyAdapter
    }.freeze

    # @param lead [Lead]
    # @param profile [Profile]
    # @return [Hash] { success: Boolean, response: { adapter: String, payload: Hash } }
    def self.call(lead:, profile:)
      new(lead:, profile:).call
    end

    def call
      adapter_class = ADAPTERS[lead.ats_type]

      unless adapter_class
        return {
          success: false,
          response: { error: "UNSUPPORTED_ATS", ats_type: lead.ats_type, fallback_url: lead.url }
        }
      end

      adapter_class.call(lead:, profile:)
    end
  end
end

# app/services/apply/base_adapter.rb
# Shared behavior for all ATS adapters
module Apply
  class BaseAdapter
    attr_reader :lead, :profile

    def self.call(lead:, profile:)
      new(lead:, profile:).call
    end

    def initialize(lead:, profile:)
      @lead = lead
      @profile = profile
    end

    def call
      form_fields = fetch_form_fields
      return form_fields unless form_fields[:success]

      payload = map_fields(form_fields[:response][:fields])

      application = lead.create_application!(
        status: :draft,
        ats_type: lead.ats_type,
        form_payload: payload
      )

      {
        success: true,
        response: {
          application_id: application.id,
          adapter: self.class.name,
          fields: form_fields[:response][:fields],
          payload:,
          apply_url: build_apply_url
        }
      }
    end

    private

    def fetch_form_fields
      raise NotImplementedError, "#{self.class} must implement #fetch_form_fields"
    end

    def map_fields(fields)
      raise NotImplementedError, "#{self.class} must implement #map_fields"
    end

    def build_apply_url
      raise NotImplementedError, "#{self.class} must implement #build_apply_url"
    end

    # Shared field mapping logic
    def base_field_map
      {
        "first_name" => profile.full_name&.split(" ")&.first,
        "last_name"  => profile.full_name&.split(" ")&.last,
        "email"      => profile.email,
        "phone"      => profile.phone,
        "linkedin"   => profile.linkedin_url,
        "github"     => profile.github_url,
        "website"    => profile.website_url,
        "location"   => profile.location
      }
    end
  end
end

# app/services/apply/greenhouse_adapter.rb
module Apply
  class GreenhouseAdapter < BaseAdapter
    private

    def fetch_form_fields
      url = "https://boards-api.greenhouse.io/v1/boards/#{lead.ats_company_slug}/jobs/#{lead.ats_job_id}"
      response = HTTParty.get(url)
      return { success: false, response: { error: "GH_API_ERROR" } } unless response.success?

      questions = response.parsed_response["questions"] || []
      fields = questions.map do |q|
        { name: q["label"], type: q["type"], required: q["required"], options: q["values"] }
      end

      { success: true, response: { fields: } }
    end

    def map_fields(fields)
      mapping = base_field_map.merge(profile.common_answers || {})
      fields.each_with_object({}) do |field, result|
        key = normalize_field_name(field[:name])
        result[field[:name]] = mapping[key] if mapping[key]
      end
    end

    def build_apply_url
      "https://boards.greenhouse.io/#{lead.ats_company_slug}/jobs/#{lead.ats_job_id}#app"
    end

    def normalize_field_name(name)
      name.to_s.downcase.gsub(/[^a-z0-9]/, "_").gsub(/_+/, "_").strip
    end
  end
end

# app/services/apply/lever_adapter.rb
module Apply
  class LeverAdapter < BaseAdapter
    private

    def fetch_form_fields
      url = "https://api.lever.co/v0/postings/#{lead.ats_company_slug}/#{lead.ats_job_id}"
      response = HTTParty.get(url)
      return { success: false, response: { error: "LEVER_API_ERROR" } } unless response.success?

      data = response.parsed_response
      fields = (data["lists"] || []).flat_map do |list|
        (list["content"]&.scan(/\b(?:name|email|phone|resume|linkedin|github)\b/i) || []).map do |f|
          { name: f, type: "text", required: true }
        end
      end

      # Lever has standard fields always
      fields = [
        { name: "name", type: "text", required: true },
        { name: "email", type: "email", required: true },
        { name: "phone", type: "phone", required: false },
        { name: "resume", type: "file", required: true },
        { name: "urls[LinkedIn]", type: "url", required: false },
        { name: "urls[GitHub]", type: "url", required: false }
      ]

      { success: true, response: { fields: } }
    end

    def map_fields(fields)
      {
        "name"           => profile.full_name,
        "email"          => profile.email,
        "phone"          => profile.phone,
        "urls[LinkedIn]" => profile.linkedin_url,
        "urls[GitHub]"   => profile.github_url
      }
    end

    def build_apply_url
      "https://jobs.lever.co/#{lead.ats_company_slug}/#{lead.ats_job_id}/apply"
    end
  end
end

# app/services/apply/ashby_adapter.rb
module Apply
  class AshbyAdapter < BaseAdapter
    private

    def fetch_form_fields
      url = "https://api.ashbyhq.com/posting-api/job-board/#{lead.ats_company_slug}"
      response = HTTParty.get(url)
      return { success: false, response: { error: "ASHBY_API_ERROR" } } unless response.success?

      jobs = response.parsed_response["jobs"] || []
      job = jobs.find { |j| j["id"] == lead.ats_job_id }
      return { success: false, response: { error: "ASHBY_JOB_NOT_FOUND" } } unless job

      form = job["applicationForm"] || {}
      fields = (form["sections"] || []).flat_map do |section|
        (section["fields"] || []).map do |f|
          { name: f["title"], type: f["type"], required: f["isRequired"] }
        end
      end

      { success: true, response: { fields: } }
    end

    def map_fields(fields)
      mapping = base_field_map.merge(profile.common_answers || {})
      fields.each_with_object({}) do |field, result|
        key = normalize_field_name(field[:name])
        result[field[:name]] = mapping[key] if mapping[key]
      end
    end

    def build_apply_url
      "https://jobs.ashbyhq.com/#{lead.ats_company_slug}/#{lead.ats_job_id}/application"
    end

    def normalize_field_name(name)
      name.to_s.downcase.gsub(/[^a-z0-9]/, "_").gsub(/_+/, "_").strip
    end
  end
end
```

---

## 4. Model Design

### ActiveRecord Models

```ruby
# app/models/profile.rb
class Profile < ApplicationRecord
  has_one :matching_criterion, dependent: :destroy
  has_many :search_queries, dependent: :destroy
  has_many :leads, dependent: :destroy
  has_one_attached :resume

  validates :full_name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  accepts_nested_attributes_for :matching_criterion

  # @return [String] first name extracted from full_name
  def first_name
    full_name&.split(" ")&.first
  end

  # @return [String] last name extracted from full_name
  def last_name
    full_name&.split(" ")&.drop(1)&.join(" ")
  end
end

# app/models/matching_criterion.rb
class MatchingCriterion < ApplicationRecord
  belongs_to :profile

  validates :min_match_score, numericality: {
    only_integer: true, in: 0..100, allow_nil: true
  }
  validates :min_salary, numericality: { only_integer: true, allow_nil: true }
  validates :max_salary, numericality: { only_integer: true, allow_nil: true }
  validates :remote_preference, inclusion: {
    in: %w[remote hybrid onsite any], allow_nil: true
  }

  # Default threshold for LLM match
  def effective_threshold
    min_match_score || 60
  end
end

# app/models/search_query.rb
class SearchQuery < ApplicationRecord
  belongs_to :profile
  has_many :leads, dependent: :nullify

  validates :ats_portal, presence: true
  validates :role_keyword, presence: true

  scope :enabled, -> { where(enabled: true) }

  SUPPORTED_PORTALS = %w[
    jobs.lever.co
    boards.greenhouse.io
    jobs.ashbyhq.com
    jobs.jobvite.com
    myworkdayjobs.com
    careers.jobscore.com
    ats.comparably.com
  ].freeze

  validates :ats_portal, inclusion: { in: SUPPORTED_PORTALS }

  # @return [Boolean] whether query was run within last 24 hours
  def recently_run?
    last_run_at.present? && last_run_at > 24.hours.ago
  end
end

# app/models/lead.rb
class Lead < ApplicationRecord
  belongs_to :profile
  belongs_to :search_query, optional: true
  has_one :application, dependent: :destroy
  has_many :notes, dependent: :destroy
  has_many :lead_events, dependent: :destroy

  enum :stage, {
    discovered:       0,
    pending_matching: 1,
    new:              2,
    reviewed:         3,
    applied:          4,
    interview:        5,
    offer:            6,
    rejected:         7
  }, default: :discovered, validate: true

  validates :title, presence: true
  validates :url, presence: true
  validates :fingerprint, presence: true, uniqueness: true
  validates :match_score, numericality: { in: 0..100, allow_nil: true }

  scope :on_board, -> { where(stage: %i[new reviewed applied interview offer]) }
  scope :by_stage, ->(stage) { where(stage:).order(stage_position: :asc) }
  scope :unmatched, -> { where(stage: :discovered) }
  scope :pending_evaluation, -> { where(stage: :pending_matching) }
  scope :recent, -> { order(discovered_at: :desc) }

  acts_as_list scope: [:profile_id, :stage], column: :stage_position

  before_validation :compute_fingerprint, on: :create

  # @param new_stage [Symbol] the target stage
  # @param trigger [String] what caused the move
  def move_to!(new_stage, trigger: "manual")
    old_stage = stage
    update!(stage: new_stage)
    lead_events.create!(from_stage: old_stage, to_stage: new_stage, trigger:)
  end

  private

  def compute_fingerprint
    self.fingerprint = Digest::SHA256.hexdigest(url) if url.present? && fingerprint.blank?
  end
end

# app/models/application.rb
class Application < ApplicationRecord
  belongs_to :lead

  enum :status, {
    draft:     0,
    submitted: 1,
    failed:    2,
    manual:    3
  }, default: :draft, validate: true

  validates :lead_id, uniqueness: true

  scope :recent, -> { order(created_at: :desc) }
end

# app/models/note.rb
class Note < ApplicationRecord
  belongs_to :lead

  validates :content, presence: true

  scope :recent, -> { order(created_at: :desc) }
end

# app/models/lead_event.rb
class LeadEvent < ApplicationRecord
  belongs_to :lead

  validates :from_stage, presence: true
  validates :to_stage, presence: true
  validates :trigger, presence: true

  scope :recent, -> { order(created_at: :desc) }
end
```

### Design Rationale: Callbacks vs Service Objects

| Pattern | Where Used | Why |
|---------|-----------|-----|
| `before_validation` | `Lead#compute_fingerprint` | Pure data derivation from existing attributes. No side effects. |
| Service object | All external API calls, matching, apply | Side effects (HTTP, LLM, state transitions). Must be testable in isolation. |
| No `after_save` callbacks | Anywhere | State transitions trigger background jobs. Callbacks would create hidden coupling and make testing hell. |

### Concerns

```ruby
# app/models/concerns/stageable.rb
# NOT NEEDED — single model (Lead) handles stages. Would be premature abstraction.
# Revisit only if another model needs stage management.
```

**No concerns in MVP.** Concerns are for shared behavior across multiple models. With one primary model (`Lead`), concerns add indirection without value.

---

## 5. Controller & View Design

### Controllers

```ruby
# app/controllers/dashboard_controller.rb
# Main Kanban board view
class DashboardController < ApplicationController
  def show
    @profile = Profile.first # Single-tenant
    @stages = Lead.stages.keys.select { |s| s.in?(%w[new reviewed applied interview offer rejected]) }
    @leads_by_stage = @stages.index_with do |stage|
      @profile.leads.by_stage(stage).includes(:application)
    end
  end
end

# app/controllers/leads_controller.rb
class LeadsController < ApplicationController
  def index
    @leads = current_profile.leads.on_board.includes(:application).order(match_score: :desc)
  end

  def show
    @lead = current_profile.leads.find(params[:id])
    @notes = @lead.notes.recent
    @application = @lead.application
    @events = @lead.lead_events.recent
  end

  # PATCH /leads/:id/move — called by SortableJS drag-and-drop
  def move
    @lead = current_profile.leads.find(params[:id])
    @lead.move_to!(params[:stage], trigger: "user_drag")
    @lead.insert_at(params[:position].to_i) if params[:position]

    respond_to do |format|
      format.turbo_stream
      format.json { render json: { success: true, stage: @lead.stage } }
    end
  end

  # POST /leads/:id/apply — trigger assisted apply
  def apply
    @lead = current_profile.leads.find(params[:id])
    result = Apply::Orchestrator.call(lead: @lead, profile: current_profile)

    if result[:success]
      @lead.move_to!(:applied, trigger: "assisted_apply")
      redirect_to @lead, notice: "Application prepared. Review and submit."
    else
      redirect_to @lead, alert: result[:response][:error]
    end
  end

  private

  def current_profile
    @current_profile ||= Profile.first # Single-tenant MVP
  end
end

# app/controllers/profiles_controller.rb
class ProfilesController < ApplicationController
  def show
    @profile = Profile.first_or_initialize
  end

  def update
    @profile = Profile.first_or_initialize
    if @profile.update(profile_params)
      redirect_to profile_path, notice: "Profile updated."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:profile).permit(
      :full_name, :email, :phone, :linkedin_url, :github_url,
      :website_url, :location, :resume_text, :cover_letter, :resume,
      common_answers: {},
      matching_criterion_attributes: [
        :id, :min_match_score, :min_salary, :max_salary,
        :remote_preference,
        required_keywords: [], negative_keywords: [],
        preferred_keywords: [], locations: [], employment_types: []
      ]
    )
  end
end

# app/controllers/search_queries_controller.rb
class SearchQueriesController < ApplicationController
  def index
    @queries = current_profile.search_queries.order(:ats_portal)
  end

  def new
    @query = current_profile.search_queries.build
  end

  def create
    @query = current_profile.search_queries.build(query_params)
    if @query.save
      redirect_to search_queries_path, notice: "Query added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @query = current_profile.search_queries.find(params[:id])
    if @query.update(query_params)
      redirect_to search_queries_path, notice: "Query updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    current_profile.search_queries.find(params[:id]).destroy
    redirect_to search_queries_path, notice: "Query removed."
  end

  # POST /search_queries/:id/run — manual trigger
  def run
    @query = current_profile.search_queries.find(params[:id])
    DiscoveryJob.perform_later(@query.id)
    redirect_to search_queries_path, notice: "Discovery job enqueued."
  end

  private

  def current_profile
    @current_profile ||= Profile.first
  end

  def query_params
    params.require(:search_query).permit(
      :ats_portal, :role_keyword, :location_keyword, :extra_terms, :enabled
    )
  end
end

# app/controllers/notes_controller.rb
class NotesController < ApplicationController
  def create
    @lead = Lead.find(params[:lead_id])
    @note = @lead.notes.build(note_params)

    if @note.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @lead }
      end
    else
      redirect_to @lead, alert: "Note could not be saved."
    end
  end

  private

  def note_params
    params.require(:note).permit(:content)
  end
end
```

### Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  resource :dashboard, only: :show, controller: "dashboard"
  resource :profile, only: [:show, :update]

  resources :search_queries do
    member do
      post :run
    end
  end

  resources :leads, only: [:index, :show] do
    member do
      patch :move
      post :apply
    end
    resources :notes, only: :create
  end

  root "dashboard#show"
end
```

### View Structure & Turbo/Stimulus Architecture

```
app/views/
├── dashboard/
│   └── show.html.erb           # Main Kanban board
├── leads/
│   ├── show.html.erb           # Lead detail page
│   ├── _card.html.erb          # Lead card partial (used in kanban columns)
│   ├── move.turbo_stream.erb   # Turbo Stream for drag-and-drop update
│   └── _match_badge.html.erb   # Score/recommendation badge
├── profiles/
│   ├── show.html.erb           # Profile form (edit inline)
│   └── _form.html.erb          # Profile form partial
├── search_queries/
│   ├── index.html.erb          # List queries
│   ├── _form.html.erb          # Query form
│   └── new.html.erb
├── notes/
│   ├── create.turbo_stream.erb # Append new note via Turbo Stream
│   └── _note.html.erb          # Single note partial
└── layouts/
    ├── application.html.erb    # Main layout with nav
    └── _nav.html.erb           # Navigation partial
```

### Kanban Board Implementation

```erb
<%# app/views/dashboard/show.html.erb %>
<div class="flex gap-4 overflow-x-auto p-4" data-controller="kanban">
  <% @stages.each do |stage| %>
    <div class="flex-shrink-0 w-80 bg-gray-50 rounded-lg p-3"
         data-controller="sortable-column"
         data-sortable-column-stage-value="<%= stage %>">

      <h2 class="font-bold text-lg mb-3 capitalize">
        <%= stage.humanize %>
        <span class="text-sm text-gray-500">
          (<%= @leads_by_stage[stage].size %>)
        </span>
      </h2>

      <div class="space-y-2 min-h-[200px]"
           data-sortable-column-target="list"
           data-stage="<%= stage %>">
        <% @leads_by_stage[stage].each do |lead| %>
          <%= render "leads/card", lead: lead %>
        <% end %>
      </div>
    </div>
  <% end %>
</div>
```

```erb
<%# app/views/leads/_card.html.erb %>
<%= turbo_frame_tag dom_id(lead) do %>
  <div class="bg-white rounded-lg shadow-sm p-3 cursor-grab border border-gray-200
              hover:shadow-md transition-shadow"
       draggable="true"
       data-id="<%= lead.id %>">

    <div class="flex justify-between items-start mb-2">
      <h3 class="font-semibold text-sm"><%= lead.title %></h3>
      <%= render "leads/match_badge", lead: lead if lead.match_score %>
    </div>

    <p class="text-xs text-gray-600 mb-1"><%= lead.company_name %></p>
    <p class="text-xs text-gray-400"><%= lead.location %></p>

    <div class="flex justify-between items-center mt-2">
      <% if lead.ats_type %>
        <span class="text-xs px-2 py-0.5 rounded bg-blue-100 text-blue-700 capitalize">
          <%= lead.ats_type %>
        </span>
      <% end %>
      <%= link_to "View", lead_path(lead), class: "text-xs text-indigo-600 hover:underline",
                  data: { turbo_frame: "_top" } %>
    </div>
  </div>
<% end %>
```

### Stimulus Controllers

```javascript
// app/javascript/controllers/sortable_column_controller.js
import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"
import { patch } from "@rails/request.js"

export default class extends Controller {
  static targets = ["list"]
  static values = { stage: String }

  connect() {
    this.sortable = Sortable.create(this.listTarget, {
      group: "kanban",
      draggable: "[draggable]",
      animation: 150,
      ghostClass: "opacity-30",
      onEnd: this.handleDrop.bind(this)
    })
  }

  async handleDrop(event) {
    const leadId = event.item.dataset.id
    const newStage = event.to.dataset.stage
    const newPosition = event.newIndex + 1

    const response = await patch(`/leads/${leadId}/move`, {
      body: JSON.stringify({ stage: newStage, position: newPosition }),
      contentType: "application/json",
      responseKind: "turbo-stream"
    })

    if (!response.ok) {
      // Revert: move item back to original position
      const originalList = event.from
      if (event.oldIndex < originalList.children.length) {
        originalList.insertBefore(event.item, originalList.children[event.oldIndex])
      } else {
        originalList.appendChild(event.item)
      }

      // Show error toast
      this.dispatch("error", { detail: { message: "Failed to move lead" } })
    }
  }

  disconnect() {
    this.sortable?.destroy()
  }
}

// app/javascript/controllers/toast_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { message: String, type: { type: String, default: "info" } }

  connect() {
    setTimeout(() => this.dismiss(), 5000)
  }

  dismiss() {
    this.element.classList.add("opacity-0", "transition-opacity")
    setTimeout(() => this.element.remove(), 300)
  }
}
```

### Turbo Stream Responses

```erb
<%# app/views/leads/move.turbo_stream.erb %>
<%= turbo_stream.replace dom_id(@lead) do %>
  <%= render "leads/card", lead: @lead %>
<% end %>
```

---

## 6. Background Job Design

### Job Classes

```ruby
# app/jobs/discovery_job.rb
# Runs discovery for a single search query
class DiscoveryJob < ApplicationJob
  queue_as :discovery
  limits_concurrency to: 2, key: -> { "discovery" }

  retry_on SerpApi::Error, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(search_query_id)
    query = SearchQuery.find(search_query_id)

    # Idempotency: skip if already run today
    return if query.recently_run?

    result = Discovery::QueryExecutor.call(query:)
    return unless result[:success]

    Discovery::ResultParser.call(
      serp_results: result[:response][:results],
      profile: query.profile,
      search_query: query
    )

    query.update!(last_run_at: Time.current)

    # Enqueue matching for new leads
    query.profile.leads.unmatched.find_each do |lead|
      Stage1MatchingJob.perform_later(lead.id)
    end
  end
end

# app/jobs/stage1_matching_job.rb
# Runs keyword filter (Stage 1) for a lead
class Stage1MatchingJob < ApplicationJob
  queue_as :matching
  limits_concurrency to: 10, key: -> { "stage1_matching" }

  discard_on ActiveRecord::RecordNotFound

  def perform(lead_id)
    lead = Lead.find(lead_id)

    # Idempotency: skip if already past discovery
    return unless lead.discovered?

    # Fetch full description from ATS if needed
    if lead.description.blank? && lead.ats_type.present?
      fetch_result = Discovery::AtsFetcher.call(lead:)
      if fetch_result[:success]
        lead.update!(
          description: fetch_result[:response][:description],
          company_name: fetch_result[:response][:company_name].presence || lead.company_name,
          location: fetch_result[:response][:location].presence || lead.location
        )
      end
    end

    criteria = lead.profile.matching_criterion
    result = Matching::KeywordEvaluator.call(lead:, criteria:)

    if result[:response][:pass]
      lead.update!(keyword_match: true, stage: :pending_matching)
      Stage2MatchingJob.perform_later(lead.id)
    else
      lead.update!(keyword_match: false, stage: :rejected)
    end
  end
end

# app/jobs/stage2_matching_job.rb
# Runs LLM evaluation (Stage 2) for a lead
class Stage2MatchingJob < ApplicationJob
  queue_as :matching
  limits_concurrency to: 3, key: -> { "llm_evaluation" }

  retry_on RubyLLM::Error, wait: :polynomially_longer, attempts: 3
  retry_on Net::ReadTimeout, wait: 30.seconds, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(lead_id)
    lead = Lead.find(lead_id)

    # Idempotency: skip if already evaluated
    return unless lead.pending_matching?

    result = Matching::LlmEvaluator.call(lead:)

    if result[:success]
      response = result[:response]
      threshold = lead.profile.matching_criterion&.effective_threshold || 60

      lead.update!(
        match_score:          response[:score],
        match_recommendation: response[:recommendation],
        match_reasoning:      response[:reasoning],
        match_strengths:      response[:strengths],
        match_concerns:       response[:concerns],
        stage: response[:score] >= threshold ? :new : :rejected
      )
    else
      # Leave in pending_matching — will be retried or handled manually
      Rails.logger.error("Stage 2 failed for lead", {
        event: "matching.stage2_failed",
        lead_id: lead.id,
        error: result[:response][:error]
      })
    end
  end
end

# app/jobs/full_discovery_job.rb
# Orchestrates discovery across all enabled queries for the profile
class FullDiscoveryJob < ApplicationJob
  queue_as :discovery
  limits_concurrency to: 1, key: -> { "full_discovery" }

  def perform
    profile = Profile.first # Single-tenant
    return unless profile

    profile.search_queries.enabled.find_each do |query|
      DiscoveryJob.perform_later(query.id)
    end
  end
end
```

### Queue Configuration

```yaml
# config/queue.yml (Solid Queue)
default: &default
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "discovery"
      threads: 2
      processes: 1
      polling_interval: 5
    - queues: "matching"
      threads: 3
      processes: 1
      polling_interval: 2
    - queues: "apply"
      threads: 1
      processes: 1
      polling_interval: 5
    - queues: "default,low"
      threads: 3
      processes: 1
      polling_interval: 5

development:
  <<: *default

production:
  <<: *default
```

### Recurring Jobs

```yaml
# config/recurring.yml
production:
  full_discovery:
    class: FullDiscoveryJob
    schedule: "every day at 6am"
    description: "Run discovery across all enabled search queries"

development:
  full_discovery:
    class: FullDiscoveryJob
    schedule: "every 4 hours"
    description: "Run discovery (more frequent in dev for testing)"
```

### Error Handling Strategy

| Error Type | Strategy | Max Attempts | Backoff |
|-----------|----------|-------------|---------|
| `SerpApi::Error` | Retry (transient API) | 3 | Polynomial |
| `RubyLLM::Error` | Retry (transient LLM) | 3 | Polynomial |
| `Net::ReadTimeout` | Retry (network) | 3 | 30s fixed |
| `ActiveRecord::RecordNotFound` | Discard (stale) | 0 | N/A |
| Unknown exception | Default Solid Queue behavior → failed queue | 3 | Default |

---

## 7. LLM Integration Design

### ruby_llm Configuration

```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.anthropic_api_key = Rails.application.credentials.dig(:anthropic, :api_key)

  # Connection settings
  config.request_timeout = 30
  config.max_retries = 2
end
```

### Prompt Template Design

The prompt template lives in `Matching::LlmEvaluator` (Section 3 above). Key design decisions:

1. **Structured output via JSON schema** — ruby_llm's `schema:` parameter forces the LLM to return valid JSON matching our schema. No free-form parsing.

2. **Description truncation at 3000 chars** — keeps token budget under ~800 input tokens. Claude Haiku pricing: ~$0.80/1M input tokens.

3. **Score calibration**:
   - 80-100: APPLY recommendation
   - 60-79: MAYBE recommendation
   - 0-59: SKIP recommendation
   - User-configurable threshold (default: 60)

### Cost Control Mechanisms

| Mechanism | Implementation |
|-----------|---------------|
| Stage 1 gate | Keyword filter eliminates 60-80% of leads BEFORE any LLM call |
| Description truncation | Max 3000 chars → ~800 tokens input |
| Model selection | Claude Haiku (~$0.002/eval) not Sonnet ($0.008) |
| Concurrency limit | `limits_concurrency to: 3` on Stage2MatchingJob |
| Daily discovery limit | `recently_run?` check prevents >1 SerpApi call/24h/query |
| Estimated cost | 100 leads/day × $0.002 = $0.20/day → ~$6/month |

### Structured JSON Output Schema

```ruby
# Used in LlmEvaluator — passed to ruby_llm's schema parameter
OUTPUT_SCHEMA = {
  type: "object",
  properties: {
    score:          { type: "integer", minimum: 0, maximum: 100 },
    recommendation: { type: "string", enum: %w[APPLY MAYBE SKIP] },
    reasoning:      { type: "string", maxLength: 500 },
    strengths:      { type: "array", items: { type: "string" }, maxItems: 5 },
    concerns:       { type: "array", items: { type: "string" }, maxItems: 5 }
  },
  required: %w[score recommendation reasoning strengths concerns]
}.freeze
```

---

## 8. Gemfile Dependencies

```ruby
# Gemfile

source "https://rubygems.org"

# === Core Framework ===
gem "rails", "~> 8.0"
gem "pg", "~> 1.5"                    # PostgreSQL adapter
gem "puma", "~> 6.0"                  # Web server
gem "solid_queue", "~> 1.1"           # Background jobs (Rails 8 default, no Redis)
gem "mission_control-jobs", "~> 0.6"  # Job monitoring UI at /jobs

# === Frontend ===
gem "importmap-rails", "~> 2.1"       # JS management without Node.js
gem "turbo-rails", "~> 2.0"           # Hotwire Turbo
gem "stimulus-rails", "~> 1.3"        # Hotwire Stimulus
gem "tailwindcss-rails", "~> 3.0"     # Utility-first CSS
gem "propshaft"                        # Asset pipeline (Rails 8 default)

# === External APIs ===
gem "serpapi", "~> 2.0"               # SerpApi client for Google SERP queries
gem "ruby_llm", "~> 1.2"             # LLM integration (Claude Haiku via Anthropic)
gem "httparty", "~> 0.22"            # HTTP client for ATS public APIs

# === Models & Data ===
gem "acts_as_list", "~> 1.2"          # Position ordering for Kanban cards

# === Utilities ===
gem "jbuilder", "~> 2.13"             # JSON response builder

group :development, :test do
  gem "rspec-rails", "~> 7.1"         # Test framework
  gem "factory_bot_rails", "~> 6.5"   # Test factories
  gem "shoulda-matchers", "~> 6.4"    # Model spec helpers
  gem "debug"                          # Debugger
  gem "dotenv-rails", "~> 3.1"        # Local env vars (.env)
end

group :development do
  gem "web-console"                    # Console in browser
  gem "rubocop-rails-omakase"          # Rails default linter
end

group :test do
  gem "vcr", "~> 6.3"                 # Record HTTP interactions for tests
  gem "webmock", "~> 3.24"            # Stub HTTP requests in tests
  gem "capybara", "~> 3.40"           # System tests
  gem "selenium-webdriver", "~> 4.27"  # Browser driver for system tests
end
```

### Dependency Justification

| Gem | Why Not Alternative |
|-----|-------------------|
| `serpapi` | Official SerpApi gem. No alternative needed. |
| `ruby_llm` | By thoughtbot. Structured output. Multi-provider. Beats direct `anthropic` SDK for flexibility. |
| `httparty` | Simple HTTP client for ATS APIs. Lighter than Faraday for these straightforward GET/POST calls. |
| `acts_as_list` | Proven gem for position management. Writing our own would be reinventing. |
| `vcr` + `webmock` | Record real API responses for test replay. Critical for testing SerpApi and ATS integrations without hitting live APIs. |
| No `devise` | Single-tenant MVP. No auth needed. Add later when multi-user. |
| No `aasm` | Lead stages are a simple integer enum with `move_to!` method. AASM is overkill for 7 fixed states with no complex guard logic. |
| No `json-ld` | Not needed — we're using SerpApi (structured JSON already) and ATS public APIs (structured JSON). No HTML parsing of JSON-LD tags. |
| No `rubycrawl`/`ferrum` | No browser scraping in MVP. SerpApi + ATS APIs cover all sources. |

---

## 9. File Structure

```
app/
├── controllers/
│   ├── application_controller.rb
│   ├── dashboard_controller.rb        # Kanban board main view
│   ├── leads_controller.rb            # Lead CRUD, move, apply actions
│   ├── notes_controller.rb            # Note creation (Turbo Stream)
│   ├── profiles_controller.rb         # Profile CRUD
│   └── search_queries_controller.rb   # Search query CRUD + manual run
├── jobs/
│   ├── application_job.rb
│   ├── discovery_job.rb               # Per-query SerpApi discovery
│   ├── full_discovery_job.rb          # Orchestrates all queries (cron)
│   ├── stage1_matching_job.rb         # Keyword filter per lead
│   └── stage2_matching_job.rb         # LLM evaluation per lead
├── javascript/
│   └── controllers/
│       ├── index.js
│       ├── sortable_column_controller.js  # SortableJS drag-and-drop
│       └── toast_controller.js            # Dismissible notifications
├── models/
│   ├── application_record.rb
│   ├── application.rb                 # ATS application record
│   ├── lead.rb                        # Core: job posting + pipeline state
│   ├── lead_event.rb                  # Stage transition audit log
│   ├── matching_criterion.rb          # Keywords, salary, location prefs
│   ├── note.rb                        # User notes on leads
│   ├── profile.rb                     # Job seeker profile (single-tenant)
│   └── search_query.rb               # SerpApi query templates
├── services/
│   ├── apply/
│   │   ├── README.md                  # Module documentation
│   │   ├── orchestrator.rb            # ATS type detection + dispatch
│   │   ├── base_adapter.rb            # Shared adapter behavior
│   │   ├── greenhouse_adapter.rb      # Greenhouse form fetch + map
│   │   ├── lever_adapter.rb           # Lever form fetch + map
│   │   └── ashby_adapter.rb           # Ashby form fetch + map
│   ├── discovery/
│   │   ├── README.md                  # Module documentation
│   │   ├── orchestrator.rb            # Full discovery pipeline
│   │   ├── query_executor.rb          # SerpApi client wrapper
│   │   ├── result_parser.rb           # SERP result → Lead records
│   │   ├── ats_detector.rb            # URL → ATS type detection
│   │   └── ats_fetcher.rb             # ATS public API client
│   └── matching/
│       ├── README.md                  # Module documentation
│       ├── orchestrator.rb            # Stage 1 → Stage 2 pipeline
│       ├── keyword_evaluator.rb       # Stage 1: deterministic filter
│       └── llm_evaluator.rb           # Stage 2: Claude Haiku scoring
└── views/
    ├── dashboard/
    │   └── show.html.erb              # Kanban board
    ├── layouts/
    │   ├── application.html.erb       # Main layout
    │   └── _nav.html.erb              # Navigation
    ├── leads/
    │   ├── show.html.erb              # Lead detail
    │   ├── _card.html.erb             # Kanban card partial
    │   ├── _match_badge.html.erb      # Score badge
    │   └── move.turbo_stream.erb      # Drag-drop response
    ├── notes/
    │   ├── _note.html.erb             # Note partial
    │   └── create.turbo_stream.erb    # Append note
    ├── profiles/
    │   ├── show.html.erb              # Profile form
    │   └── _form.html.erb             # Form partial
    └── search_queries/
        ├── index.html.erb             # Query list
        ├── new.html.erb               # New query
        └── _form.html.erb             # Query form partial

config/
├── initializers/
│   └── ruby_llm.rb                   # LLM configuration
├── queue.yml                          # Solid Queue worker config
├── recurring.yml                      # Cron-like scheduled jobs
└── routes.rb                          # Application routes

db/
└── migrate/
    ├── 001_create_profiles.rb
    ├── 002_create_matching_criteria.rb
    ├── 003_create_search_queries.rb
    ├── 004_create_leads.rb
    ├── 005_create_applications.rb
    ├── 006_create_notes.rb
    └── 007_create_lead_events.rb

spec/
├── models/
│   ├── lead_spec.rb
│   ├── profile_spec.rb
│   ├── matching_criterion_spec.rb
│   ├── search_query_spec.rb
│   ├── application_spec.rb
│   └── note_spec.rb
├── services/
│   ├── discovery/
│   │   ├── query_executor_spec.rb
│   │   ├── result_parser_spec.rb
│   │   ├── ats_detector_spec.rb
│   │   └── ats_fetcher_spec.rb
│   ├── matching/
│   │   ├── keyword_evaluator_spec.rb
│   │   └── llm_evaluator_spec.rb
│   └── apply/
│       ├── orchestrator_spec.rb
│       ├── greenhouse_adapter_spec.rb
│       ├── lever_adapter_spec.rb
│       └── ashby_adapter_spec.rb
├── jobs/
│   ├── discovery_job_spec.rb
│   ├── stage1_matching_job_spec.rb
│   └── stage2_matching_job_spec.rb
├── requests/
│   ├── dashboard_spec.rb
│   ├── leads_spec.rb
│   ├── profiles_spec.rb
│   └── search_queries_spec.rb
├── system/
│   └── kanban_board_spec.rb
├── factories/
│   ├── profiles.rb
│   ├── leads.rb
│   ├── matching_criteria.rb
│   ├── search_queries.rb
│   ├── applications.rb
│   └── notes.rb
└── support/
    ├── vcr_setup.rb
    └── factory_bot.rb
```

### Organization Rationale

- **Services in domain modules** (`discovery/`, `matching/`, `apply/`): Each module is a bounded context with its own README. Clear ownership.
- **No `lib/`**: Everything lives in `app/services/`. Rails autoloads `app/` — no need for `lib/` complexity.
- **Jobs mirror services**: `DiscoveryJob` → `Discovery::Orchestrator`. Jobs are thin — load record, guard for idempotency, delegate to service.
- **One Stimulus controller per behavior**: `sortable_column_controller` handles drag-drop. `toast_controller` handles notifications. No god controllers.

---

## 10. Security Considerations

### API Key Management

```yaml
# config/credentials.yml.enc (via rails credentials:edit)
serp_api_key: sk_serp_...
anthropic:
  api_key: sk-ant-...
```

- **NEVER** in `.env` files, environment variables in production, or committed code
- Rails credentials encrypted at rest with `config/master.key`
- `master.key` in `.gitignore` (Rails default)
- Development: use `dotenv-rails` with `.env.local` (gitignored) for convenience

### Data Privacy

| Data | Storage | Protection |
|------|---------|-----------|
| Resume text | `profiles.resume_text` (PostgreSQL) | Single-tenant, no external access |
| Resume file | ActiveStorage (local disk in dev, S3 in prod) | Pre-signed URLs, not public |
| API keys | `credentials.yml.enc` | AES-256-GCM encryption |
| Job descriptions | `leads.description` (PostgreSQL) | Fetched from public APIs, not sensitive |
| Common answers | `profiles.common_answers` (JSONB) | Contains personal info — no external access |
| LLM prompts | Sent to Anthropic API | Anthropic's data retention policy applies. Don't send SSN/financial data. |

### Rate Limiting & Abuse Prevention

| Resource | Limit | Implementation |
|----------|-------|---------------|
| SerpApi calls | 1 per query per 24h | `SearchQuery#recently_run?` check in `DiscoveryJob` |
| Claude API calls | 3 concurrent max | `limits_concurrency to: 3` on `Stage2MatchingJob` |
| ATS API calls | 2 concurrent max | `limits_concurrency to: 2` on `DiscoveryJob` |
| Full discovery | 1 concurrent max | `limits_concurrency to: 1` on `FullDiscoveryJob` |

### Single-Tenant Security Model

- **No authentication in MVP**: Single user, local machine or personal server
- **No CSRF concerns for API calls**: All state changes go through standard Rails forms with CSRF tokens
- **Content Security Policy**: Default Rails 8 CSP headers. Add `sortablejs` CDN to allowed scripts.
- **SQL Injection**: ActiveRecord parameterized queries. No raw SQL.
- **XSS**: Rails auto-escapes all output. `strip_tags` on ATS HTML descriptions before storing.

---

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit (models) | Validations, enums, scopes, `move_to!`, `recently_run?` | RSpec model specs, shoulda-matchers |
| Unit (services) | Keyword evaluator logic, ATS detector, result parser | RSpec service specs, mock HTTP calls |
| Integration (services) | SerpApi client, ATS fetcher, LLM evaluator | VCR cassettes with real API recordings |
| Integration (jobs) | Job enqueue chains, idempotency guards, retry config | `queue_adapter = :test`, `have_enqueued_job` |
| Request | Controller actions, Turbo Stream responses, routing | RSpec request specs |
| System | Kanban drag-and-drop, profile form, search query CRUD | Capybara + Selenium (headless Chrome) |

---

## Migration / Rollout

No migration needed — this is a greenfield project. The rollout order is:

1. `rails new the-interview --database=postgresql --css=tailwind --skip-jbuilder`
2. Add gems to Gemfile, `bundle install`
3. Run migrations in order (001-007)
4. Seed initial Profile record
5. Configure credentials (`rails credentials:edit`)
6. Configure Solid Queue (`config/queue.yml` + `config/recurring.yml`)
7. Pin SortableJS (`bin/importmap pin sortablejs`)

---

## Open Questions

- [ ] **SortableJS version**: Pin via importmap — need to verify latest ESM-compatible version
- [ ] **ruby_llm structured output**: Verify `schema:` parameter works with Claude Haiku specifically (may need `tool_use` mode instead)
- [ ] **ActiveStorage for resume**: Local disk OK for MVP? Or S3 from day one?
- [ ] **Cover letter templating**: Simple `gsub` with `{{company}}`/`{{role}}`? Or use ERB/Liquid?
- [ ] **Ashby API**: Their posting API docs are less documented than Greenhouse/Lever — may need exploration during implementation
