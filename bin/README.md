# `bin/`

Save your custom scripts here. **Ensure these scripts are executable**. You can set the executable permission using:

```
chmod +x <script_name>
```

Any executable scripts in the `bin/` directory can be called directly from any process, as if they were any other command line tool. For example, a script called `your_script.sh` placed in the `bin/` directory can be called as follows::

```
process EXAMPLE {
    input:
    path input_file

    output:
    path "output.file"

    script:
    """
    your_script.sh ${input_file} > output.file
    """
}
```
