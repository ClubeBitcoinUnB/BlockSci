//
//  blocksci_type_converter.cpp
//  blocksci
//
//  Created by Harry Kalodner on 11/25/18.
//

#include "blocksci_type_converter.hpp"

#include "python_fwd.hpp"

#include <blocksci/address/address.hpp>
#include <blocksci/chain/block.hpp>
#include <blocksci/chain/block_range.hpp>
#include <blocksci/chain/input.hpp>
#include <blocksci/chain/input_range.hpp>
#include <blocksci/chain/output.hpp>
#include <blocksci/chain/output_range.hpp>
#include <blocksci/scripts/script_variant.hpp>

#include <range/v3/view/any_view.hpp>

blocksci::AnyScript BlockSciTypeConverter::operator()(const blocksci::Address &address) const {
  return address.getScript();
}

RawRange<blocksci::Input> BlockSciTypeConverter::operator()(const blocksci::InputRange &val) const {
  return ranges::any_view<blocksci::Input, random_access_sized>{val};
}

RawRange<blocksci::Output> BlockSciTypeConverter::operator()(const blocksci::OutputRange &val) const {
  return ranges::any_view<blocksci::Output, random_access_sized>{val};
}

RawRange<blocksci::Block> BlockSciTypeConverter::operator()(const blocksci::BlockRange &val) const {
  return ranges::any_view<blocksci::Block, random_access_sized>{val};
}
