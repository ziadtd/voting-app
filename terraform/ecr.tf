resource "aws_ecr_repository" "vote" {
  name                 = "voting-app/vote"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

resource "aws_ecr_repository" "result" {
  name                 = "voting-app/result"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

resource "aws_ecr_repository" "worker" {
  name                 = "voting-app/worker"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

resource "aws_ecr_repository" "seed" {
  name                 = "voting-app/seed"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}
