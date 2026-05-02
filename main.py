"""MkDocs macros plugin — computes template variables at build time."""
import os
import json


def define_env(env):
    """Define variables available as {{ var }} in all Markdown pages."""
    # Count skill directories
    skill_dirs = sorted([
        d for d in os.listdir('skills/')
        if os.path.isdir(os.path.join('skills/', d))
    ])

    # Read version from package.json
    with open('package.json', encoding='utf-8') as f:
        version = json.load(f)['version']

    env.variables['skill_count'] = len(skill_dirs)
    env.variables['invocable_count'] = len(skill_dirs) - 1  # minus using-superpowers
    env.variables['version'] = version
    env.variables['skill_names'] = skill_dirs
