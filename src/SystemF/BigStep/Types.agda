module SystemF.BigStep.Types where

open import Prelude
open import Data.List as List

-- types are indexed by the number of open tvars
infixl 10 _⇒_
data Type (n : ℕ) : Set where
  Unit : Type n
  ν    : (i : Fin n) → Type n
  _⇒_  : Type n → Type n → Type n
  ∀'   : Type (suc n) → Type n

open import Data.Fin.Substitution
open import Data.Vec hiding (_∈_; map)

module App {T} (l : Lift T Type )where

  open Lift l hiding (var)
  _/_  : ∀ {m n} → Type m → Sub T m n → Type n
  Unit / s = Unit
  ν i / s = lift (lookup i s)
  (a ⇒ b) / s = (a / s) ⇒ (b / s)
  ∀' x / s = ∀' (x / (s ↑))

  open Application (record { _/_ = _/_ }) using (_/✶_)

  open import Data.Star

  Unit-/✶-↑✶ : ∀ k {m n} (ρs : Subs T m n) → Unit /✶ ρs ↑✶ k ≡ Unit
  Unit-/✶-↑✶ k ε = refl
  Unit-/✶-↑✶ k (x ◅ ρs) = cong₂ _/_ (Unit-/✶-↑✶ k ρs) refl

  ∀-/✶-↑✶ : ∀ k {m n t} (ρs : Subs T m n) →
            ∀' t /✶ ρs ↑✶ k ≡ ∀' (t /✶ ρs ↑✶ suc k)
  ∀-/✶-↑✶ k ε        = refl
  ∀-/✶-↑✶ k (ρ ◅ ρs) = cong₂ _/_ (∀-/✶-↑✶ k ρs) refl

  ⇒-/✶-↑✶ : ∀ k {m n t₁ t₂} (ρs : Subs T m n) →
            t₁ ⇒ t₂ /✶ ρs ↑✶ k ≡ (t₁ /✶ ρs ↑✶ k) ⇒ (t₂ /✶ ρs ↑✶ k)
  ⇒-/✶-↑✶ k ε        = refl
  ⇒-/✶-↑✶ k (ρ ◅ ρs) = cong₂ _/_ (⇒-/✶-↑✶ k ρs) refl

tmSubst : TermSubst Type
tmSubst = record { var = ν; app = App._/_ }

open TermSubst tmSubst hiding (var; subst) public

-- typing context
Ctx : ℕ → Set
Ctx n = List (Type n)

_+tm_ : ∀ {n} → Ctx n → Type n → Ctx n
Γ +tm a = a ∷ Γ

Var : ∀ {n} → Ctx n → Type n → Set
Var Γ a = a ∈ Γ
  where
    open import Data.List.Any
    open Membership-≡

infixl 30 _ctx/_
_ctx/_ : ∀ {n m} → Ctx n → Sub Type n m → Ctx m
Γ ctx/ ρ = List.map (flip _/_ ρ) Γ

_+ty  : ∀ {n} → Ctx n → Ctx (suc n)
Γ +ty = Γ ctx/ wk

module Lemmas where

  open import Data.Fin.Substitution.Lemmas

  tyLemmas : TermLemmas Type
  tyLemmas = record
    { termSubst = tmSubst
    ; app-var   = refl
    ; /✶-↑✶     = Lemma./✶-↑✶
    }
    where
    module Lemma {T₁ T₂} {lift₁ : Lift T₁ Type} {lift₂ : Lift T₂ Type} where

      open Lifted lift₁ using () renaming (_↑✶_ to _↑✶₁_; _/✶_ to _/✶₁_)
      open Lifted lift₂ using () renaming (_↑✶_ to _↑✶₂_; _/✶_ to _/✶₂_)

      /✶-↑✶ : ∀ {m n} (ρs₁ : Subs T₁ m n) (ρs₂ : Subs T₂ m n) →
              (∀ k x → ν x /✶₁ ρs₁ ↑✶₁ k ≡ ν x /✶₂ ρs₂ ↑✶₂ k) →
              ∀ k t → t /✶₁ ρs₁ ↑✶₁ k ≡ t /✶₂ ρs₂ ↑✶₂ k
      /✶-↑✶ ρs₁ ρs₂ hyp k Unit =
        begin _ ≡⟨ App.Unit-/✶-↑✶ _ k ρs₁ ⟩ Unit ≡⟨ sym $ App.Unit-/✶-↑✶ _ k ρs₂ ⟩ _ ∎
      /✶-↑✶ ρs₁ ρs₂ hyp k (ν i) = hyp k i
      /✶-↑✶ ρs₁ ρs₂ hyp k (a ⇒ b) = begin
        _ ≡⟨ App.⇒-/✶-↑✶ _ k ρs₁ ⟩
        (a /✶₁ ρs₁ ↑✶₁ k) ⇒ (b /✶₁ ρs₁ ↑✶₁ k) ≡⟨ cong₂ _⇒_ (/✶-↑✶ ρs₁ ρs₂ hyp k a)
                                                           ((/✶-↑✶ ρs₁ ρs₂ hyp k b)) ⟩
        (a /✶₂ ρs₂ ↑✶₂ k) ⇒ (b /✶₂ ρs₂ ↑✶₂ k) ≡⟨ sym $ App.⇒-/✶-↑✶ _ k ρs₂ ⟩
        _ ∎
      /✶-↑✶ ρs₁ ρs₂ hyp k (∀' x) = begin
        _ ≡⟨ App.∀-/✶-↑✶ _ k ρs₁ ⟩
          ∀' (x /✶₁ ρs₁ ↑✶₁ (suc k)) ≡⟨ cong ∀' (/✶-↑✶ ρs₁ ρs₂ hyp (suc k) x) ⟩
        ∀' (x /✶₂ ρs₂ ↑✶₂ (suc k)) ≡⟨ sym $ App.∀-/✶-↑✶ _ k ρs₂ ⟩
        _ ∎

  open TermLemmas tyLemmas public hiding (var)

module CtxLemmas where

  open import Data.List.Properties as ListProp using ()
  open import Function as Fun

  -- weakening followed by sub disappears on contexts
  ctx/-wk-sub≡id : ∀ {n} (Γ : Ctx n) a → (Γ ctx/ wk) ctx/ (sub a) ≡ Γ
  ctx/-wk-sub≡id Γ a = begin
    _ ≡⟨ sym (ListProp.map-compose Γ) ⟩
    map (λ x → x / wk / (sub a)) Γ ≡⟨ ListProp.map-cong Lemmas.wk-sub-vanishes Γ ⟩
    map Fun.id Γ ≡⟨ ListProp.map-id Γ ⟩
    _ ∎

  -- weakening commutes with other substitutions on contexts
  ctx/-wk-comm : ∀ {n m} (Γ : Ctx n) (ρ : Sub Type n m) → (Γ ctx/ ρ) ctx/ wk ≡ Γ ctx/ wk ctx/ (ρ ↑)
  ctx/-wk-comm Γ ρ = begin
    _ ≡⟨ sym $ ListProp.map-compose Γ ⟩
    map (λ x → x / ρ / wk) Γ ≡⟨ ListProp.map-cong Lemmas.wk-commutes Γ ⟩
    map (λ x → x / wk / ρ ↑) Γ ≡⟨ ListProp.map-compose Γ ⟩
    _ ∎
