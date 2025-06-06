use malachite_core_types::{Context, NilOrVal, Round, ValueId, VoteType};

#[derive(Clone)]
pub struct MalachiteContext {}

// impl Context for MalachiteContext {
//     type Address = BasePeerAddress;
//     type Height = BaseHeight;
//     type ProposalPart = BaseProposalPart;
//     type Proposal = BaseProposal;
//     type Validator = BasePeer;
//     type ValidatorSet = BasePeerSet;
//     type Value = BaseValue;
//     type Vote = BaseVote;
//     type SigningScheme = signing_scheme::Ed25519;
//     type SigningProvider = BaseSigningProvider;
//     type Extension = Extension;

//     fn select_proposer<'a>(
//         &self,
//         validator_set: &'a Self::ValidatorSet,
//         _height: Self::Height,
//         _round: Round,
//     ) -> &'a Self::Validator {
//         // Keep it simple, the proposer is always the same peer
//         validator_set
//             .peers
//             .first()
//             .expect("no peer found in the validator set")
//     }

//     fn signing_provider(&self) -> &Self::SigningProvider {
//         &self.signing_provider
//     }

//     fn new_proposal(
//         height: Self::Height,
//         round: Round,
//         value: Self::Value,
//         _pol_round: Round,
//         address: Self::Address,
//     ) -> Self::Proposal {
//         BaseProposal {
//             height,
//             value,
//             proposer: address,
//             round,
//         }
//     }

//     fn new_prevote(
//         height: Self::Height,
//         round: Round,
//         value_id: NilOrVal<ValueId<Self>>,
//         address: Self::Address,
//     ) -> Self::Vote {
//         BaseVote {
//             vote_type: VoteType::Prevote,
//             height,
//             value_id,
//             round,
//             voter: address,
//             // TODO: A bit strange there is option to put extension into Prevotes
//             //  clarify.
//             extension: None,
//         }
//     }

//     fn new_precommit(
//         height: Self::Height,
//         round: Round,
//         value_id: NilOrVal<ValueId<Self>>,
//         address: Self::Address,
//     ) -> Self::Vote {
//         BaseVote {
//             vote_type: VoteType::Precommit,
//             height,
//             value_id,
//             round,
//             voter: address,
//             extension: None,
//         }
//     }
// }
