use reth_chainspec::ChainSpec;
use reth_consensus::{Consensus, ConsensusError };
use reth_node_builder::{Block, components::ConsensusBuilder, BuilderContext, FullNodeTypes};
// use reth_primitives::Block;

use std::sync::Arc;

#[derive(Debug, Default, Clone)]
pub struct MalachiteConsensus {
    chain_spec: Arc<ChainSpec>,
}

impl MalachiteConsensus {
    pub fn new(chain_spec: Arc<ChainSpec>) -> Self {
        Self { chain_spec }
    }
}

#[derive(Debug, Default, Clone, Copy)]
pub struct MalachiteConsensusBuilder {}

// impl<Node, B> ConsensusBuilder<Node> for MalachiteConsensusBuilder
// where
//     Node: FullNodeTypes,
//     B: Block,
// {
//     type Consensus = Arc<dyn Consensus<B>>;

//     async fn build_consensus(self, ctx: &BuilderContext<Node>) -> eyre::Result<Self::Consensus> {
//         Ok(Arc::new(MalachiteConsensus::new(ctx.chain_spec())))
//     }
// }