import ProvenZk.Binary
import ProvenZk.Hash
import ProvenZk.Merkle
import ProvenZk.Ext.Vector

import FormalVerification
import FormalVerification.Poseidon.Spec
import FormalVerification.Poseidon.Correctness
import FormalVerification.SemanticEquivalence

open SemaphoreMTB (F Order)

variable [Fact (Nat.Prime Order)]

open SemaphoreMTB renaming VerifyProof_4_3 → gVerifyProof
open SemaphoreMTB renaming DeletionRound_3_3 → gDeletionRound
open SemaphoreMTB renaming DeletionProof_2_2_3_2_2_3 → gDeletionProof
open SemaphoreMTB renaming InsertionRound_3_3 → gInsertionRound
open SemaphoreMTB renaming InsertionProof_2_3_2_2_3 → gInsertionProof

def TreeInsert [Fact (perfect_hash poseidon₂)] (Tree : MerkleTree F poseidon₂ D) (Index Item : F) (Proof : Vector F D) (k : F → Prop): Prop :=
  MerkleTree.item_at_nat Tree Index.val = some 0 ∧
  MerkleTree.proof_at_nat Tree Index.val = some Proof.reverse ∧
  ∃postTree, MerkleTree.set_at_nat Tree Index.val Item = some postTree ∧
  k postTree.root

theorem insertion_round_uncps [Fact (perfect_hash poseidon₂)] (Tree : MerkleTree F poseidon₂ D) (Index Item : F) (Proof : Vector F D) (k : F → Prop):
  insertion_round Index Item Tree.root Proof k ↔
  TreeInsert Tree Index Item Proof k := by
  unfold insertion_round
  unfold TreeInsert
  apply Iff.intro
  . rintro ⟨ixbin, _⟩
    casesm* (_ ∧ _)
    have : nat_to_bits_le D Index.val = some (vector_zmod_to_bit ixbin) := by
      apply recover_binary_zmod'_to_bits_le
      . simp
      . assumption
      . assumption
    unfold MerkleTree.item_at_nat
    unfold MerkleTree.proof_at_nat
    unfold MerkleTree.set_at_nat
    unfold Dir.nat_to_dir_vec
    rw [this]
    simp [←Dir.create_dir_vec_bit]
    refine ⟨?_, ⟨?_, ?_⟩⟩
    . apply MerkleTree.proof_ceritfies_item (proof := Proof.reverse)
      simpa [←MerkleTree.recover_tail_reverse_equals_recover]
    . apply MerkleTree.recover_proof_reversible
      rw [←MerkleTree.recover_tail_reverse_equals_recover]
      simpa
    . rw [←MerkleTree.proof_insert_invariant (proof := Proof.reverse) (old := 0)]
      . rw [←MerkleTree.recover_tail_reverse_equals_recover]
        simpa
      . rw [←MerkleTree.recover_tail_reverse_equals_recover]
        simpa
  . rintro ⟨hitem, ⟨hproof, ⟨ftree, ⟨hftree, hresult⟩⟩⟩⟩
    simp [MerkleTree.item_at_nat, Dir.nat_to_dir_vec] at hitem
    rcases hitem with ⟨bits, ⟨hbits, hitem_at⟩⟩
    simp [MerkleTree.proof_at_nat, Dir.nat_to_dir_vec] at hproof
    rcases hproof with ⟨bits', ⟨hbits', hproof_at⟩⟩
    simp [hbits] at hbits'
    subst_vars
    simp [MerkleTree.set_at_nat, Dir.nat_to_dir_vec] at hftree
    rcases hftree with ⟨bits'', ⟨hbits'', hftree_at⟩⟩
    simp [hbits''] at hbits
    rw [←Vector.vector_reverse_eq] at hproof_at
    subst_vars
    exists (bits''.map Bit.toZMod)
    refine ⟨?_, ⟨?_, ⟨?_, ?_⟩⟩⟩
    . apply recover_binary_of_to_bits
      assumption
    . apply vector_binary_of_bit_to_zmod
    . rw [MerkleTree.recover_tail_equals_recover_reverse, Dir.create_dir_vec_bit, zmod_to_bit_coe, ←hitem_at]
      simp [MerkleTree.recover_proof_is_root]
    . rw [MerkleTree.recover_tail_equals_recover_reverse, Dir.create_dir_vec_bit, zmod_to_bit_coe]
      rw [MerkleTree.proof_insert_invariant _]
      . assumption
      . exact 0
      . rw [← hitem_at]
        simp [MerkleTree.recover_proof_is_root]

theorem item_at_invariant { depth : Nat } {F: Type} {H : Hash F 2} {tree : MerkleTree F H depth} {ix₁ ix₂ : Vector Dir depth} {item₁ : F} {neq : ix₁ ≠ ix₂}:
  MerkleTree.item_at (tree.set ix₁ item₁) ix₂ = tree.item_at ix₂ := by
  induction depth with
  | zero =>
    cases ix₁ using Vector.casesOn
    cases ix₂ using Vector.casesOn
    cases (neq rfl)
  | succ depth ih =>
    cases ix₁ using Vector.casesOn; rename_i ix₁_hd ix₁_tl
    cases ix₂ using Vector.casesOn; rename_i ix₂_hd ix₂_tl
    cases tree; rename_i tree_l tree_r
    simp [MerkleTree.item_at, MerkleTree.set, MerkleTree.tree_for, MerkleTree.set, MerkleTree.left, MerkleTree.right]
    simp [Vector.vector_eq_cons] at neq
    cases ix₁_hd <;> { cases ix₂_hd <;> { simp [ih, neq] } }

theorem vector_reverse_inj {a b : Vector α d} : Vector.reverse a = Vector.reverse b ↔ a = b := by
  apply Iff.intro
  . intro h
    induction d with
    | zero =>
      cases a using Vector.casesOn
      cases b using Vector.casesOn
      rfl
    | succ d ih =>
      cases a using Vector.revCasesOn
      cases b using Vector.revCasesOn
      simp [Vector.eq_cons_iff] at h
      cases h;
      subst_vars
      congr
      apply ih
      assumption
  . intro h; congr

theorem vector_map_inj {a b : Vector α d} {f_inj : ∀ a b, f a = f b → a = b}: a.map f = b.map f ↔ a = b := by
  apply Iff.intro
  . intro h
    induction d with
    | zero =>
      cases a using Vector.casesOn
      cases b using Vector.casesOn
      rfl
    | succ d ih =>
      cases a using Vector.casesOn
      cases b using Vector.casesOn
      simp [Vector.eq_cons_iff] at h
      rcases h with ⟨h, t⟩
      have := f_inj _ _ h
      have := ih t
      congr

theorem nat_to_dir_vec_unique {ix₁ ix₂ : Nat} {r₁ r₂ : Vector Dir d}:
  Dir.nat_to_dir_vec ix₁ d = some r₁ → Dir.nat_to_dir_vec ix₂ d = some r₂ → r₁ = r₂ → ix₁ = ix₂ := by
  simp [Dir.nat_to_dir_vec]
  intros
  subst_vars
  rw [←recover_binary_nat_to_bits_le, vector_reverse_inj, vector_map_inj] at *
  subst_vars
  rfl
  . intro a b; cases a <;> { cases b <;> tauto }


theorem item_at_nat_invariant {H : Hash α 2} {tree tree': MerkleTree α H depth} { neq : ix₁ ≠ ix₂ }:
  MerkleTree.set_at_nat tree ix₁ item₁ = some tree' →
  MerkleTree.item_at_nat tree' ix₂ = MerkleTree.item_at_nat tree ix₂ := by
  simp [MerkleTree.set_at_nat, MerkleTree.item_at_nat]
  intros; subst_vars
  cases h : Dir.nat_to_dir_vec ix₂ depth with
  | none => rfl
  | some ix =>
    simp
    rw [item_at_invariant]
    intro hp
    refine (neq ?_)
    apply nat_to_dir_vec_unique <;> assumption

theorem zmod_eq { a b : F} : a = b ↔ a.val = b.val := by
  apply Iff.intro
  . intros; simp [*]
  . intros
    cases a; cases b;
    congr

theorem before_insertion_all_items_zero_loop
  [Fact (perfect_hash poseidon₂)]
  {Tree: MerkleTree F poseidon₂ D}
  {StartIndex B: Nat}
  {ixBound: StartIndex + B < Order}
  {IdComms: Vector F B} {MerkleProofs: Vector (Vector F D) B} {k: F -> Prop}:
  insertion_rounds ↑StartIndex Tree.root IdComms MerkleProofs k →
  (∀ i ∈ [StartIndex:StartIndex + B], MerkleTree.item_at_nat Tree i = some 0) := by
  induction B generalizing StartIndex Tree with
  | zero =>
    intro _ i range
    rcases range with ⟨lo, hi⟩
    have := Nat.ne_of_lt (Nat.lt_of_le_of_lt lo hi)
    contradiction
  | succ B ih =>
    intro hp i range
    rcases range with ⟨lo, hi⟩; simp at lo hi
    have hStartIndexCast : ZMod.val (StartIndex : F) = StartIndex := by
      apply ZMod.val_cast_of_lt
      linarith
    cases lo with
    | refl =>
      simp [insertion_rounds,  InsertionRound_uncps, insertion_round_uncps, TreeInsert, hStartIndexCast] at hp
      cases hp
      assumption
    | @step StartIndex' h =>
      have : (StartIndex : F) + 1 = ((StartIndex + 1 : Nat) : F) := by
        apply zmod_eq.mpr
        apply Eq.symm
        apply Eq.trans
        apply ZMod.val_cast_of_lt
        . calc
            StartIndex + 1 ≤ StartIndex + B.succ := by simp_arith
            _ < Order := ixBound
        . rw [ZMod.val_add, hStartIndexCast, Nat.mod_eq_of_lt]
          rfl
          calc
            StartIndex + ZMod.val (1 : F) ≤ StartIndex + B.succ := by
              conv => lhs; arg 2; whnf
              simp_arith
            _ < Order := ixBound
      rw [insertion_rounds,  InsertionRound_uncps, insertion_round_uncps, TreeInsert, this] at hp
      rcases hp with ⟨_, ⟨_, ⟨postTree, ⟨hinsert, hnext⟩⟩⟩⟩
      rw [←item_at_nat_invariant hinsert]
      apply ih hnext StartIndex'.succ
      . apply And.intro
        . simp_arith; assumption
        . simp; linarith
      . linarith
      . rw [hStartIndexCast]
        apply Nat.ne_of_lt
        simp_arith
        assumption

theorem before_insertion_all_items_zero
  [Fact (perfect_hash poseidon₂)]
  {Tree: MerkleTree F poseidon₂ D}
  (StartIndex: Nat) (IdComms: Vector F B) (MerkleProofs: Vector (Vector F D) B) (k: F -> Prop)
  {ixBound: StartIndex + B < Order}:
  gInsertionProof ↑StartIndex Tree.root IdComms MerkleProofs k →
  (∀ i ∈ [StartIndex:StartIndex + B], MerkleTree.item_at_nat Tree i = some 0) := by
  rw [InsertionProof_looped]
  apply before_insertion_all_items_zero_loop
  assumption

def main : IO Unit := pure ()