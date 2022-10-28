# Xen NFT

This is a Xen NFT project.

## Installation

```bash
npm install
```

## Tests

```bash
npm run test
```

## Code Style

https://docs.soliditylang.org/en/latest/style-guide.html

> Check code lint

```bash
npm run lint
```

> Fix code lint

```bash
npm run lint:fix
```

### Git Hook

This project uses [Husky](https://typicode.github.io/husky/#/) to run git hooks. The `pre-commit`
hook runs `lint-staged` to run code lint checking and code formatting before committing.

> Install Husky hooks

```shell
npm run husky:install
```
