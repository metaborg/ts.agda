module Impure.LFRef.Syntax where

open import Prelude
open import Data.Vec hiding ([_]; map)
open import Data.List hiding ([_])
open import Data.List.All hiding (lookup)

data Term : (n : ℕ) → Set
data Type : (n : ℕ) → Set

data Term where
  var : ∀ {n} → Fin n → Term n
  loc : ∀ {n} → ℕ → Term n
  unit : ∀ {n} → Term n

  -- constructor application
  con : ∀ {n} → (fn : ℕ) → (ts : List (Term n)) → Term n

infixl 30 _·★_
data Exp : ℕ → Set where
  -- basic lambda expressions
  tm : ∀ {n} → Term n → Exp n

  -- function calls
  _·★_ : ∀ {n} → (fn : ℕ) → (as : List (Term n)) → Exp n

  -- heap manipulation
  ref : ∀ {n} → Exp n → Exp n
  !_ : ∀ {n} → Exp n → Exp n
  _≔_ : ∀ {n} → Exp n → Exp n → Exp n

data SeqExp : ℕ → Set where
  lett : ∀ {n} → (x : Exp n) → (e : SeqExp (suc n)) → SeqExp n
  ret  : ∀ {n} → Exp n → SeqExp n

data Val : Term 0 → Set where
  loc : ∀ {i} → Val (loc i)
  unit : Val unit
  con : ∀ {k ts} → Val (con k ts)

data ExpVal : Exp zero → Set where
  tm : ∀ {t} → Val t → ExpVal (tm t)

data SeqExpVal : SeqExp zero → Set where
  ret-tm : ∀ {t} → Val t → SeqExpVal (ret (tm t))

-- telescoped contexts/arguments
data Tele : (n m : ℕ) → Set where
  ε : ∀ {n} → Tele n 0
  _⟶_ : ∀ {m n} → Type n → Tele (suc n) m → Tele n (suc m)

infixl 20 _[_]
data Type where
  _[_] : ∀ {n} → ℕ → (ts : List (Term n)) → Type n
  Ref : ∀ {n} → (A : Type n) → Type n
  Unit : ∀ {n} → Type n

Store : Set
Store = List (∃ Val)

record ConType : Set where
  field
    m : ℕ
    args : Tele 0 m
    tp   : ℕ
    indices : List (Term m)

record Fun : Set where
  field
    m : ℕ
    args : Tele 0 m
    returntype : Type m
    body : Exp m

record Sig : Set where
  field
    types : List (∃ (Tele 0))
    constructors : List ConType
    funs : List Fun

open import Data.Fin.Substitution

module App {T} (l : Lift T Term) where
  open Lift l

  _tp/_ : ∀ {n n'} → Type n → Sub T n n' → Type n'

  _/_ : ∀ {n n'} → Term n → Sub T n n' → Term n'
  var x / s = lift $ lookup x s
  unit / s = unit
  _/_ {n} {n'} (con c ts) s = con c (map/ ts)
    where
      -- inlined for termination checker..
      map/ : List (Term n) → List (Term n')
      map/ [] = []
      map/ (x ∷ ts₁) = x / s ∷ map/ ts₁
  loc x / s = loc x

  _tele/_ : ∀ {n m n'} → Tele n m → Sub T n n' → Tele n' m
  ε tele/ s = ε
  (x ⟶ t) tele/ s = (x tp/ s) ⟶ (t tele/ (s ↑))

  _tp/_ {n} {n'} (k [ ts ]) s = k [ map/ ts ]
    where
      -- inlined for termination checker..
      map/ : List (Term n) → List (Term n')
      map/ [] = []
      map/ (x ∷ ts₁) = x / s ∷ map/ ts₁
  (Ref A) tp/ s = Ref (A tp/ s)
  Unit tp/ s = Unit

  _exp/_ : ∀ {n n'} → Exp n → Sub T n n' → Exp n'
  tm x exp/ s = tm (x / s)
  _exp/_ {n} {n'} (fn ·★ ts) s = fn ·★ map/ ts
    where
      -- inlined for termination checker..
      map/ : List (Term n) → List (Term n')
      map/ [] = []
      map/ (x ∷ ts₁) = x / s ∷ map/ ts₁
  ref x exp/ s = ref (x exp/ s)
  (! x) exp/ s = ! (x exp/ s)
  (y ≔ x) exp/ s = (y exp/ s) ≔ (x exp/ s)

  _seq/_ : ∀ {n n'} → SeqExp n → Sub T n n' → SeqExp n'
  lett x e seq/ s = lett (x exp/ s) (e seq/ (s ↑))
  ret e seq/ s = ret (e exp/ s)

  open Application (record { _/_ = _/_ }) using (_/✶_)

tmSubst : TermSubst Term
tmSubst = record { var = var; app = App._/_ }

open TermSubst tmSubst hiding (var) public

open App termLift using (_exp/_; _tp/_; _tele/_; _seq/_) public
