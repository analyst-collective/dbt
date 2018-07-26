from dbt.api import APIObject

from dbt.node_types import NodeType
from dbt.utils import deep_merge


UNPARSED_BASE_CONTRACT = {
    'type': 'object',
    'additionalProperties': False,
    'properties': {
        'package_name': {
            'type': 'string',
        },
        # filesystem
        'root_path': {
            'type': 'string',
            'description': 'The absolute path to the project root',
        },
        'path': {
            'type': 'string',
            'description': (
                'Relative path to the source file from the project root. '
                'Usually the same as original_file_path, but in some cases '
                'dbt will generate a path.'),
        },
        'original_file_path': {
            'type': 'string',
            'description': (
                'Relative path to the originating file from the project root.'
                ),
        },
        'raw_sql': {
            'type': 'string',
            'description': (
                'For nodes defined in SQL files, this is just the contents '
                'of that file. For schema tests, archives, etc. this is '
                'generated by dbt.'),
        },
        'index': {
            'type': 'integer',
        }
    },
    'required': ['package_name', 'root_path', 'path', 'original_file_path',
                 'raw_sql']
}

UNPARSED_MACRO_CONTRACT = UNPARSED_BASE_CONTRACT

UNPARSED_NODE_CONTRACT = deep_merge(
    UNPARSED_BASE_CONTRACT,
    {
        'properties': {
            'name': {
                'type': 'string',
                'description': (
                    'Name of this node. For models, this is used as the '
                    'identifier in the database.'),
                'minLength': 1,
            },
            'resource_type': {
                'enum': [
                    NodeType.Model,
                    NodeType.Test,
                    NodeType.Analysis,
                    # Note: Hooks fail if you remove this, even though it's
                    # also allowed in ParsedMacro, which seems wrong.
                    # Maybe need to move hook operations into macros?
                    NodeType.Operation,
                    NodeType.Seed,
                    # we need this if parse_node is going to handle archives.
                    NodeType.Archive,
                ]
            }
        },
        'required': UNPARSED_BASE_CONTRACT['required'] + [
            'resource_type', 'name']
    }
)


class UnparsedMacro(APIObject):
    SCHEMA = UNPARSED_MACRO_CONTRACT


class UnparsedNode(APIObject):
    SCHEMA = UNPARSED_NODE_CONTRACT


COLUMN_TEST_CONTRACT = {
    'type': 'object',
    'additionalProperties': False,
    'properties': {
        'name': {
            'type': 'string',
            'description': 'The name of the column this test is for',
        },
        'description': {
            'type': 'string',
            'description': 'The description of this test',
        },
        'tests': {
            'type': 'array',
            'items': {
                "anyOf": [
                    # 'not_null', 'unique', ...
                    {'type': 'string'},
                    # 'relationships: {...}', 'accepted_values: {...}'
                    {'type': 'object', 'additionalProperties': True}
                ],
            },
            'description': 'The list of tests to perform',
        },
    },
    'required': ['name'],
}


UNPARSED_NODE_UPDATE_CONTRACT = {
    'type': 'object',
    'additionalProperties': False,
    'description': (
        'A collection of the unparsed node updates, as provided in the '
        '"models" section of schema.yml'
    ),
    'properties': {
        'name': {
            'type': 'string',
            'description': (
                'The name of this node, which is the name of the model it'
                'refers to'
            ),
            'minLength': 1,
        },
        'description': {
            'type': 'string',
            'description': (
                'The raw string description of the node after parsing the yaml'
            ),
        },
        'columns': {
            'type': 'array',
            'items': COLUMN_TEST_CONTRACT,
        },
        'tests': {
            'type': 'array',
            'items': {
                "anyOf": [
                    {'type': 'string'},
                    {'type': 'object', 'additionalProperties': True}
                ],
            },
        },
    },
    'required': ['name'],
}


class UnparsedNodeUpdate(APIObject):
    """An unparsed node update is the blueprint for tests to be added and nodes
    to be updated, referencing a certain node (specifically, a Model).
    """
    SCHEMA = UNPARSED_NODE_UPDATE_CONTRACT


UNPARSED_DOCUMENTATION_CONTRACT = {
    'type': 'object',
    'additionalProperties': False,
    'properties': {
        'name': {
            'type': 'string',
            'description': (
                'Name of this node, as referred to by doc() references'
            ),
        },
        'package_name': {
            'type': 'string',
        },
        # filesystem
        'root_path': {
            'type': 'string',
            'description': 'The absolute path to the project root',
        },
        'path': {
            'type': 'string',
            'description': (
                'Relative path to the source file from the project root. '
                'Usually the same as original_file_path, but in some cases '
                'dbt will generate a path.'),
        },
        'original_file_path': {
            'type': 'string',
            'description': (
                'Relative path to the originating file from the project root.'
                ),
        },
        'file_contents': {
            'type': 'string',
            'description': (
                'The raw text provided in the documentation block, presumably '
                'markdown.'
            ),
        },
        # TODO: I would like to remove this, but some graph error handling cares
        # about it.
        'resource_type': {
            'enum': [
                NodeType.Documentation,
            ]
        },
    },
    'required': [
        'name', 'package_name', 'root_path', 'path', 'original_file_path',
        'file_contents', 'resource_type'
    ],
}


class UnparsedDocumentation(APIObject):
    SCHEMA = UNPARSED_DOCUMENTATION_CONTRACT
