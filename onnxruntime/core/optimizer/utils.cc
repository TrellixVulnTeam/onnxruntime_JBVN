// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#include "core/common/make_unique.h"
#include "core/graph/onnx_protobuf.h"
#include "core/graph/graph_utils.h"
#include "core/framework/tensorprotoutils.h"
#include "core/optimizer/initializer.h"
#include "core/framework/utils.h"
#include "core/optimizer/utils.h"
#include "float.h"
//#include <deque>

using namespace onnxruntime;

namespace onnxruntime {
namespace optimizer_utils {

bool IsFloatingPointDataType(const ONNX_NAMESPACE::TensorProto& tensor_proto) {
  return tensor_proto.data_type() == ONNX_NAMESPACE::TensorProto_DataType_FLOAT || tensor_proto.data_type() == ONNX_NAMESPACE::TensorProto_DataType_FLOAT16 || tensor_proto.data_type() == ONNX_NAMESPACE::TensorProto_DataType_DOUBLE;
}

inline bool IsScalar(const NodeArg& input_arg) {
  auto shape = input_arg.Shape();
  if (shape == nullptr) {
    // shape inferencing wasn't able to populate shape information for this NodeArg
    return false;
  }

  auto dim_size = shape->dim_size();
  return dim_size == 0 || (dim_size == 1 && shape->dim(0).has_dim_value() && shape->dim(0).dim_value() == 1);
}

// Check whether input is a constant scalar with expected float value.
bool IsInitializerWithExpectedValue(const Graph& graph, const NodeArg& input_arg, float expected_value, bool is_constant) {
  if (!IsScalar(input_arg)) {
    return false;
  }

  const float atol = 1e-8f;
  const float rtol = 1e-5f;
  const ONNX_NAMESPACE::TensorProto* tensor_proto = nullptr;
  if (is_constant) {
    tensor_proto = graph_utils::GetConstantInitializer(graph, input_arg.Name());
  } else if (!graph.GetInitializedTensor(input_arg.Name(), tensor_proto)) {
    return false;
  }

  if (tensor_proto == nullptr) {
    return false;
  }

  auto init_const = onnxruntime::make_unique<Initializer>(*tensor_proto);
  const auto data_type = tensor_proto->data_type();
  if (data_type == ONNX_NAMESPACE::TensorProto_DataType_FLOAT) {
    const float* val = init_const->data<float>();
    if (std::isnan(val[0]) || std::isinf(val[0])) return false;

    float diff = std::abs(val[0] - expected_value);
    if (diff > (atol + rtol * std::abs(expected_value))) {
      return false;
    }
  } else if (data_type == ONNX_NAMESPACE::TensorProto_DataType_DOUBLE) {
    const double* val = init_const->data<double>();
    if (std::isnan(val[0]) || std::isinf(val[0])) return false;

    const double expected_val = static_cast<double>(expected_value);
    double diff = std::abs(val[0] - expected_val);
    if (diff > (atol + rtol * std::abs(expected_value))) {
      return false;
    }
  } else if (data_type == ONNX_NAMESPACE::TensorProto_DataType_FLOAT16) {
    const MLFloat16* val = init_const->data<MLFloat16>();
    const float flt_val = math::halfToFloat(val[0].val);
    if (std::isnan(flt_val) || std::isinf(flt_val)) return false;
    const float expected_val = math::halfToFloat(math::floatToHalf(expected_value));
    float diff = std::abs(flt_val - expected_val);
    if (diff > (atol + rtol * std::abs(expected_value))) {
      return false;
    }
  } else {
    // Not expected data types.
    return false;
  }

  return true;
}

// Check whether input is a constant scalar with expected intger value.
bool IsInitializerWithExpectedValue(const Graph& graph, const NodeArg& input_arg, int64_t expected_value, bool is_constant) {
  if (!IsScalar(input_arg)) {
    return false;
  }

  const ONNX_NAMESPACE::TensorProto* tensor_proto = nullptr;
  if (is_constant) {
    tensor_proto = graph_utils::GetConstantInitializer(graph, input_arg.Name());
  } else if (!graph.GetInitializedTensor(input_arg.Name(), tensor_proto)) {
    return false;
  }

  auto init_const = onnxruntime::make_unique<Initializer>(*tensor_proto);
  const auto data_type = tensor_proto->data_type();
  if (data_type == ONNX_NAMESPACE::TensorProto_DataType_INT64) {
    const int64_t* val = init_const->data<int64_t>();
    if (val[0] != expected_value) {
      return false;
    }
  } else if (data_type == ONNX_NAMESPACE::TensorProto_DataType_INT32) {
    const int32_t* val = init_const->data<int32_t>();
    if (static_cast<int64_t>(val[0]) != expected_value) {
      return false;
    }
  } else {
    // Not expected data types.
    return false;
  }

  return true;
}

bool IsAttributeWithExpectedValue(const Node& node, const std::string& attr_name, int64_t expected_value) {
  const auto* attr_proto = graph_utils::GetNodeAttribute(node, attr_name);
  if ((nullptr != attr_proto) && attr_proto->has_i()) {
    return attr_proto->i() == expected_value;
  }
  return false;
}

bool AppendTensorFromInitializer(const Graph& graph, const NodeArg& input_arg, std::vector<int64_t>& data) {
  const ONNX_NAMESPACE::TensorProto* tensor_proto = nullptr;
  if (!graph.GetInitializedTensor(input_arg.Name(), tensor_proto)) {
    return false;
  }

  auto init_const = onnxruntime::make_unique<Initializer>(*tensor_proto);
  const auto data_type = tensor_proto->data_type();
  if (data_type == ONNX_NAMESPACE::TensorProto_DataType_INT64) {
    const int64_t* val = init_const->data<int64_t>();
    data.reserve(data.size() + init_const->size());
    data.insert(data.end(), val, val + init_const->size());
  } else if (data_type == ONNX_NAMESPACE::TensorProto_DataType_INT32) {
    const int32_t* val = init_const->data<int32_t>();
    data.reserve(data.size() + init_const->size());
    for (int64_t i = 0; i < init_const->size(); i++) {
      data.push_back(static_cast<int64_t>(val[i]));
    }
  } else {
    return false;
  }

  return true;
}

bool ValidateShape(const NodeArg& node_arg, const std::initializer_list<int64_t>& expected_dim_values) {
  auto shape = node_arg.Shape();
  if (shape == nullptr || static_cast<size_t>(shape->dim_size()) != expected_dim_values.size()) {
    return false;
  }

  int index = 0;
  for (auto& expected_dim_value : expected_dim_values) {
    if (expected_dim_value > 0) {
      auto dim = shape->dim(index);
      if (!utils::HasDimValue(dim) || expected_dim_value != dim.dim_value()) {
        return false;
      }
    }
    ++index;
  }

  return true;
}

bool IsShapeKnownOnAllDims(const NodeArg& node_arg, int expected_dim_size) {
  auto shape = node_arg.Shape();
  if (shape == nullptr || shape->dim_size() != expected_dim_size) {
    return false;
  }

  for (int i = 0; i < expected_dim_size; i++) {
    if (!utils::HasDimValue(shape->dim(i))) {
      return false;
    }
  }

  return true;
}

int32_t IndexOfNodeInput(const Node& node, const NodeArg& node_arg) {
  int32_t index = 0;
  for (auto& input_arg : node.InputDefs()) {
    if (input_arg->Name().compare(node_arg.Name()) == 0) {
      return index;
    }
    index++;
  }

  return -1;
}

bool IsSupportedDataType(const Node& node, const std::vector<std::string>& supported_data_types) {
  for (const auto& input_arg : node.InputDefs()) {
    if (std::find(supported_data_types.begin(), supported_data_types.end(),
                  *(input_arg->Type())) == supported_data_types.end()) {
      return false;
    }
  }
  return true;
}

}  // namespace optimizer_utils
}  // namespace onnxruntime
