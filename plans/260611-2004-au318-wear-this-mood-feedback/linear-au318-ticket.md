# [UAC] Feature: Home App — Wear This Mood Feedback Experience (AU-318)

> Source: https://linear.app/duncan-1/issue/AU-318 | State: Todo | Priority: Medium | Labels: Improvement, Feature

Objective

When users accept an outfit recommendation through the “Wear this” action, the system should capture how the outfit emotionally resonates with them.

This flow exists to:

* strengthen emotional recommendation learning
* associate accepted outfits with mood signals
* improve future outfit personalization
* reinforce recommendation confidence
* understand how users emotionally experience style

The experience should feel:

* lightweight
* emotionally supportive
* fast
* optional
* non-judgmental

---

# 11\. Wear This Flow

## Updated Flow Overview

The “Wear this” action no longer immediately saves the outfit.

Instead:

1. User taps “Wear this”
2. System opens mood feedback modal
3. User optionally selects emotional feedback
4. User confirms
5. Outfit + emotional signals are saved together

The system should treat emotional feedback as:

* soft preference learning
* contextual style understanding
* non-permanent emotional state data

The system must NOT:

* psychologically profile users
* aggressively overfit mood behavior
* reduce outfit diversity excessively

---

# Mood Feedback Modal

The mood feedback modal should appear as a bottom sheet overlay.

## Modal Content

### Header

“How did this outfit feel?”

### Supporting Text

“This helps us understand your style and mood better.”

### Mood Chips

Examples:

* Feels like me
* Confident
* Relaxed
* Polished
* Comfortable
* Sharp
* Effortless
* Elevated

### CTA

Primary CTA:
“Done”

The CTA should remain disabled until:

* at least one mood chip is selected

---

# Primary Flow

## Scenario: User taps “Wear this”

Given:

* Recommendation visible
* Outfit fully loaded
* User eligible to save outfits

When:

* User taps “Wear this”

Then:

### UI:

* Open mood feedback bottom sheet
* Dim Home screen background
* Display mood chips
* Display disabled “Done” CTA initially

### Data:

* Create temporary pending outfit acceptance state
* Do NOT save outfit yet

### State:

* recommendation_state:
  * idle → awaiting_mood_feedback

### Feedback:

* No success confirmation displayed yet

---

## Scenario: User selects mood chip

Given:

* Mood feedback modal open

When:

* User taps mood chip

Then:

### UI:

* Highlight selected mood chip
* Enable “Done” CTA

### Data:

* Store selected mood tag in temporary feedback payload

### State:

* mood_feedback_state:
  * selecting

### Feedback:

* No loading interruption displayed

---

## Scenario: User selects multiple mood chips

Given:

* Mood feedback modal open

When:

* User taps multiple mood chips

Then:

### UI:

* Highlight all selected chips
* Preserve multiple selections

### Data:

* Store all selected mood values

### State:

* mood_feedback_selection_mode:
  * multi_select

### Feedback:

* No validation warning displayed

---

## Scenario: User deselects mood chip

Given:

* Mood chip already selected

When:

* User taps selected chip again

Then:

### UI:

* Remove selected highlight state

### Data:

* Remove mood value from temporary payload

### State:

* mood_feedback_state remains active

### Feedback:

* No interruption displayed

---

## Scenario: User submits mood feedback

Given:

* At least one mood chip selected

When:

* User taps “Done”

Then:

### UI:

* Close mood feedback modal
* Show success confirmation banner
* Preserve current outfit view
* Highlight successful save state

### Data:

* Save outfit into Favorite Collection
* Save selected emotional tags linked to outfit
* Save recommendation acceptance event
* Reinforce emotional preference learning
* Save submission timestamp

### State:

* recommendation_state:
  * awaiting_mood_feedback → accepted
* mood_feedback_state:
  * submitting → success

### Feedback:

Display:
“This look is now saved to your favorites.”

---

# Secondary Flows

## Scenario: User dismisses mood modal

Given:

* Mood feedback modal open

When:

* User closes modal using swipe-down gesture or outside tap

Then:

### UI:

* Close modal
* Return to Home screen

### Data:

* Outfit NOT saved
* No emotional feedback stored

### State:

* recommendation_state:
  * awaiting_mood_feedback → idle

### Feedback:

* No success banner displayed

---

## Scenario: User taps “Wear this” again after dismissal

Given:

* User previously dismissed mood modal
* Outfit still active

When:

* User taps “Wear this” again

Then:

### UI:

* Reopen fresh mood modal
* Clear previous temporary selections

### Data:

* Prevent duplicate pending records

### State:

* mood_feedback_state:
  * reset

### Feedback:

* No loading interruption displayed

---

# Contextual Mood Intelligence

Mood chips should adapt subtly based on recommendation context.

The system should dynamically prioritize emotionally relevant chips.

## Example Context Mapping

### Work Context

* Professional
* Sharp
* Prepared
* Polished

### Weekend Context

* Relaxed
* Easy
* Comfortable
* Effortless

### Social Context

* Attractive
* Elevated
* Confident
* Expressive

### Travel Context

* Functional
* Comfortable
* Lightweight
* Relaxed

The system should preserve:

* emotional consistency
* chip readability
* limited cognitive load

The system must NOT:

* overload users with too many chips

Recommended maximum:

* 6–8 visible chips

---

# Recommendation Learning Rules

The emotional feedback system should use:

* weighted recency
* soft preference learning
* gradual emotional decay

## Recency Weighting

| Time Range | Influence |
| -- | -- |
| Last 7 days | High |
| Last 30 days | Medium |
| Historical baseline | Soft influence |

Recent moods should influence recommendations more strongly than older moods.

---

---

# Recommendation Confidence Rules

## Signal Strength Hierarchy

| User Action | Learning Strength |
| -- | -- |
| Wear + mood submitted | Strong positive |
| Wear only | Medium positive |
| Mood modal skipped | Neutral |
|  |  |

Skipped mood feedback should NOT be treated as rejection.

---

# Mood Prompt Frequency Rules

Mood prompts should reduce over time as the system confidence improves.

## Suggested Frequency Model

| User Maturity | Prompt Frequency |
| -- | -- |
| New users | Every save |
| Learning phase | Frequent |
| Mature profile | Occasional |
| High-confidence profile | Contextual only |

The system should intelligently re-trigger prompts when:

* recommendation confidence drops
* user behavior changes
* style experimentation increases
* context changes significantly

---

# Error Handling

## Scenario: Mood feedback submission fails

Given:

* User taps “Done”

When:

* API request fails

Then:

### UI:

* Keep modal open
* Preserve selected chips
* Re-enable CTA

### Data:

* No outfit save created
* No emotional linkage stored

### State:

* mood_feedback_state:
  * submitting → error

### Feedback:

Display:
“Unable to save your feedback. Please try again.”

---

## Scenario: Network timeout during submission

Given:

* Mood feedback submitting

When:

* Request exceeds timeout threshold

Then:

### UI:

* Stop loading state
* Preserve modal state

### Data:

* Prevent duplicate save attempts

### State:

* mood_feedback_state:
  * timeout

### Feedback:

Display:
“Connection timed out. Please try again.”

---

# Edge Cases

## Scenario: User rapidly taps “Wear this”

Given:

* Recommendation visible

When:

* User taps “Wear this” repeatedly

Then:

### UI:

* Open only one modal instance

### Data:

* Prevent duplicate pending save records

### State:

* modal_state:
  * locked_until_rendered

### Feedback:

* No duplicated animation displayed

---

## Scenario: Outfit already exists in Favorites

Given:

* Outfit previously saved

When:

* User submits mood feedback again

Then:

### UI:

* Preserve successful flow

### Data:

* Update emotional linkage only
* Prevent duplicate outfit entries

### State:

* recommendation_state:
  * accepted

### Feedback:

Display:
“Mood updated for this saved look.”

---

# Analytics Events

System must additionally track:

* wear_this_clicked
* mood_feedback_opened
* mood_chip_selected
* mood_chip_deselected
* mood_feedback_submitted
* mood_feedback_skipped
* outfit_mood_linked
* negative_mood_selected
* mood_feedback_submission_failed

---

# Emotional Design Principles

The emotional feedback system should feel like:

“A stylist quietly learning your confidence patterns.”

The experience must NOT feel like:

* mood tracking
* emotional surveillance
* personality analysis
* therapy
* journaling

The product tone should remain:

* calm
* stylish
* supportive
* emotionally lightweight

---

# 🔴 High-risk Scenarios

* Emotional prompts become repetitive
* Users feel psychologically analyzed
* Recommendation diversity collapses from overfitting
* Duplicate saves created from retries
* Mood chips become emotionally ambiguous
* Frequent prompts create decision fatigue
* Negative feedback excessively narrows recommendations

---

# ⚠️ Gaps / Final Decisions

* Mood prompts become progressively less frequent over time
* Custom mood text input is NOT supported in MVP
* Emotional learning uses weighted recency
* Emotional preferences decay softly over time
* Mood chips adapt subtly by context
* Negative emotional feedback supported using soft wording
* Skipped prompts treated as neutral signals
* Emotional insights may surface subtly in future iterations