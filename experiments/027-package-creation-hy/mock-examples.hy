;; Mock examples using the Nonsense Provider in Hy
;; Demonstrates usage patterns for the custom Pulumi package

(import pulumi)
(import [pulumi-nonsense :as nonsense])
(import json)
(import uuid)
(import datetime)

;; Configuration
(setv config (pulumi.Config))
(setv environment (pulumi.get-stack))

;; Provider configuration
(setv nonsense-provider
  (nonsense.Provider "nonsense-provider"
    :nonsense-level "high"
    :enable-chaos True
    :quantum-state "superposition"
    :temporal-stability-factor 0.7
    :universal-constants {:speed-of-light 299792458
                          :plancks-constant 6.62607015e-34
                          :answer-to-everything 42}))

;; 1. Create a Magical Unicorn
(setv sparklehorn
  (nonsense.MagicalUnicorn "sparklehorn"
    :name "Sparklehorn the Magnificent"
    :horn-length 2.5
    :rainbow-intensity 85
    :magical-properties {:spell-power 75
                        :enchantment-type "lightning"
                        :runic-inscriptions ["THUNDER" "STORM" "POWER" "MAGIC"]
                        :magical-reagents {:dragon-scale 3
                                          :unicorn-hair 12
                                          :pixie-dust 5.5}
                        :mana-capacity 8500.0
                        :is-blessed True}
    :preferred-habitat "cloud_castle"
    :opts (pulumi.ResourceOptions :provider nonsense-provider)))

;; 2. Create a Quantum Cat (Schrödinger's Resource)
(setv quantum-cat
  (nonsense.SchrodingersResource "quantum-cat"
    :name "quantum-cat-experiment-001"
    :initial-state "superposition"
    :quantum-properties {:wave-function "ψ(x,t) = α|alive⟩ + β|dead⟩"
                        :observer-effect False
                        :entangled-with []
                        :probability-cloud {:state-alive 0.5
                                           :state-dead 0.5}
                        :uncertainty-principle {:position-uncertainty 1e-10
                                               :momentum-uncertainty 1e-24}
                        :coherence-time 1000.0}
    :half-life 42.0
    :isolation-level "maximum"
    :opts (pulumi.ResourceOptions :provider nonsense-provider)))

;; 3. Create an Infinite Monkey
(setv shakespeare-monkey
  (nonsense.InfiniteMonkey "shakespeare-monkey"
    :name "Sir Typesworth McBanana"
    :typewriter-model "Quantum-Typewriter"
    :initial-speed 80
    :opts (pulumi.ResourceOptions :provider nonsense-provider)))

;; 4. Create a Time Paradox
(setv bootstrap-paradox
  (nonsense.TimeParadox "bootstrap-paradox"
    :name "The Bootstrap Enigma"
    :paradox-type "bootstrap"
    :target-timestamp (.isoformat (.utcnow datetime.datetime))
    :severity-level 7
    :opts (pulumi.ResourceOptions :provider nonsense-provider)))

;; 5. Entangled Quantum Resources (demonstrate dependencies)
(setv quantum-dog
  (nonsense.SchrodingersResource "quantum-dog"
    :name "quantum-dog-experiment-002"
    :initial-state "entangled-pair"
    :quantum-properties {:wave-function "ψ(x,t) = (|happy⟩|sad⟩ - |sad⟩|happy⟩)/√2"
                        :observer-effect False
                        :entangled-with [(. quantum-cat urn)]
                        :probability-cloud {:state-happy 0.5
                                           :state-sad 0.5}
                        :coherence-time 500.0}
    :half-life 84.0
    :isolation-level "standard"
    :opts (pulumi.ResourceOptions 
           :provider nonsense-provider
           :depends-on [quantum-cat])))

;; 6. Create another Unicorn with different properties
(setv moonbeam
  (nonsense.MagicalUnicorn "moonbeam"
    :name "Moonbeam Starwhisper"
    :horn-length 1.8
    :rainbow-intensity 95
    :magical-properties {:spell-power 90
                        :enchantment-type "time-warp"
                        :runic-inscriptions ["TIME" "SPACE" "MOON" "STAR" "WHISPER"]
                        :magical-reagents {:dragon-scale 5
                                          :unicorn-hair 20
                                          :pixie-dust 10.0}
                        :mana-capacity 9500.0
                        :is-blessed True}
    :preferred-habitat "starlight_meadow"
    :opts (pulumi.ResourceOptions :provider nonsense-provider)))

;; 7. Generate nonsensical text using provider function
(setv jabberwocky-text
  (nonsense.generate-nonsense
    :length 300
    :style "jabberwocky"
    :include-emojis True
    :complexity-level 0.8
    :seed-value 12345))

(setv quantum-babble
  (nonsense.generate-nonsense
    :length 150
    :style "quantum-physics"
    :include-emojis False
    :complexity-level 0.9
    :seed-value 67890))

;; 8. Validate quantum states
(setv cat-validation
  (nonsense.validate-quantum-state
    :wave-function "ψ(x,t) = α|alive⟩ + β|dead⟩"
    :observer-present False
    :measurement-type "superposition"
    :temperature 0.001
    :isolation-quality 0.95))

(setv dog-validation
  (nonsense.validate-quantum-state
    :wave-function "ψ(x,t) = (|happy⟩|sad⟩ - |sad⟩|happy⟩)/√2"
    :observer-present False
    :measurement-type "entanglement"
    :temperature 0.01
    :isolation-quality 0.8))

;; 9. Create resources with complex interdependencies
(setv temporal-lab
  (nonsense.TimeParadox "temporal-lab"
    :name "The Quantum Unicorn Paradox"
    :paradox-type "causal-loop"
    :target-timestamp (.isoformat (datetime.datetime 2025 12 31 23 59 59))
    :severity-level 9
    :opts (pulumi.ResourceOptions 
           :provider nonsense-provider
           :depends-on [sparklehorn moonbeam quantum-cat])))

;; 10. Multiple monkeys for literature production
(setv monkey-collective [])
(for [i (range 5)]
  (setv monkey-name f"monkey-{i}")
  (setv typewriter-models ["Remington" "Underwood" "Smith-Corona" "Royal" "Quantum-Typewriter"])
  (setv monkey
    (nonsense.InfiniteMonkey monkey-name
      :name f"Literary Monkey #{i}"
      :typewriter-model (get typewriter-models (% i (len typewriter-models)))
      :initial-speed (+ 30 (* i 10))
      :opts (pulumi.ResourceOptions :provider nonsense-provider)))
  (.append monkey-collective monkey))

;; Export resource outputs for inspection
(pulumi.export "magical-creatures"
  {:sparklehorn-location (. sparklehorn location)
   :sparklehorn-visibility (. sparklehorn is-visible)
   :moonbeam-location (. moonbeam location)
   :moonbeam-visibility (. moonbeam is-visible)})

(pulumi.export "quantum-experiments"
  {:cat-state (. quantum-cat state)
   :cat-last-observed (. quantum-cat last-observed)
   :dog-state (. quantum-dog state)
   :dog-last-observed (. quantum-dog last-observed)
   :entanglement-active (bool (. quantum-dog quantum-properties entangled-with))})

(pulumi.export "literary-production"
  {:shakespeare-monkey-words (. shakespeare-monkey words-per-minute)
   :shakespeare-works-completed (. shakespeare-monkey shakespeare-count)
   :current-composition (. shakespeare-monkey current-work)
   :monkey-count (len monkey-collective)})

(pulumi.export "temporal-anomalies"
  {:bootstrap-paradox-timeline (. bootstrap-paradox timeline-id)
   :bootstrap-causality (. bootstrap-paradox causality-integrity)
   :temporal-lab-severity (. temporal-lab severity-level)
   :temporal-lab-timeline (. temporal-lab timeline-id)})

(pulumi.export "generated-content"
  {:jabberwocky {:text (. jabberwocky-text text)
                 :word-count (. jabberwocky-text word-count)
                 :nonsense-rating (. jabberwocky-text nonsense-rating)}
   :quantum-babble {:text (. quantum-babble text)
                    :word-count (. quantum-babble word-count)
                    :nonsense-rating (. quantum-babble nonsense-rating)}})

(pulumi.export "quantum-validations"
  {:cat-experiment {:valid (. cat-validation is-valid)
                    :probability (. cat-validation probability)
                    :collapsed (. cat-validation collapsed)}
   :dog-experiment {:valid (. dog-validation is-valid)
                    :probability (. dog-validation probability)
                    :collapsed (. dog-validation collapsed)}})

;; Export provider configuration summary
(pulumi.export "provider-config"
  {:nonsense-level "high"
   :chaos-enabled True
   :quantum-state "superposition"
   :temporal-stability 0.7
   :universal-constants {:speed-of-light 299792458
                        :answer-to-everything 42}})

;; Export resource summary
(pulumi.export "resource-summary"
  {:magical-unicorns 2
   :quantum-resources 2
   :infinite-monkeys 6
   :time-paradoxes 2
   :total-resources 12
   :environment environment
   :nonsense-level "MAXIMUM"})

;; Mock deployment instructions
(pulumi.export "deployment-notes"
  {:instructions "Deploy with extreme caution - may cause reality distortions"
   :prerequisites ["Quantum computer recommended"
                   "Temporal shielding advised"
                   "Emergency unicorn veterinarian on standby"
                   "Paradox resolution team available"]
   :warnings ["Do not observe quantum resources directly"
              "Keep unicorns away from time paradoxes"
              "Monitor monkey output for Shakespeare detection"
              "Maintain temporal stability above 0.5"]
   :support "Contact the Department of Impossible Things for assistance"})

;; Example usage in org-mode documentation
(pulumi.export "org-mode-examples"
  {:basic-usage "#+begin_src hy\n(nonsense.MagicalUnicorn \"test\" :name \"Testicorn\" :horn-length 1.0)\n#+end_src"
   :quantum-setup "#+begin_src hy\n(nonsense.SchrodingersResource \"test\" :name \"quantum-test\" :initial-state \"superposition\")\n#+end_src"
   :function-call "#+begin_src hy\n(nonsense.generate-nonsense :length 100 :style \"jabberwocky\")\n#+end_src"})