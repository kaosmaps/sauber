import click

from .services import MainService


@click.group()
def cli():
    pass

@cli.command()
def main():
    service = MainService()
    click.echo(service.main_function())

if __name__ == "__main__":
    cli()
